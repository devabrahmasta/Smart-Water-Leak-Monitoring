/*
 * Smart Water Leak Monitoring - ESP32 Firmware
 * Hardware:
 *  - ESP32 NodeMCU / DevKit
 *  - Solenoid Valve via Relay Module (GPIO 13) - Normally Closed Logic
 *  - Flow Sensor YF-S201 (GPIO 4)
 *  - Manual Push Button (GPIO 18) - Internal Pull-Up
 *  - Status LEDs: Red (GPIO 23), Green (GPIO 33), Blue (GPIO 22)
 *
 * Sesuai CONTRACT.md bagian 2:
 *  - Topik: swm/{device_id}/telemetry, swm/{device_id}/alert, swm/{device_id}/status,
 *           swm/{device_id}/cmd, swm/{device_id}/ack
 *  - TLS: setCACert (tanpa setInsecure)
 *  - State & msg_id persistent lewat Preferences (NVS)
 */

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <time.h>

// Muat kredensial rahasia (WiFi, MQTT broker, CA Cert)
#include "secrets.h"

// ==========================================
// PINOUT HARDWARE
// ==========================================
#define PIN_FLOW_SENSOR   4
#define PIN_RELAY_VALVE   13
#define PIN_BUTTON_MANUAL 18
#define PIN_LED_RED       23
#define PIN_LED_BLUE      22
#define PIN_LED_GREEN     33

// ==========================================
// LOGIKA RELAY & VALVE (NORMALLY CLOSED)
// ==========================================
// Relay tipe NC (Normally Closed) ke Solenoid:
// - Saat NORMAL (Air BUKA): Relay OFF (tidak mengalirkan arus pemutus, valve standby terbuka)
// - Saat BOCOR / TUTUP: Relay ON (memutus jalur kontak NC sehingga valve menutup)
// Jika modul relay Active-HIGH:
#define RELAY_TRIGGER_ACTIVE   HIGH
#define RELAY_TRIGGER_INACTIVE LOW

#define VALVE_OPEN_SIGNAL      RELAY_TRIGGER_INACTIVE  // Relay OFF -> Air jalan (NC tersambung)
#define VALVE_CLOSE_SIGNAL     RELAY_TRIGGER_ACTIVE    // Relay ON  -> Air mati (NC terputus)

// ==========================================
// KONFIGURASI ATURAN & TIMING
// ==========================================
// Konversi YF-S201: L/menit = pulsa per detik / 7.5
const float FLOW_CALIBRATION_FACTOR = 7.5;

// Parameter Deteksi Kebocoran Lokal (CONTRACT.md 2.9)
// Nilai bawaan. Bisa diubah per kamar dari aplikasi lewat topik config,
// lalu disimpan di NVS (CONTRACT.md 2.10).
unsigned long continuousLeakMs = 45UL * 60UL * 1000UL; // 45 menit
unsigned long stableLeakMs     = 5UL * 60UL * 1000UL;  // 5 menit
unsigned long quietLeakMs      = 5UL * 60UL * 1000UL;  // 5 menit
int quietStartMin = 1 * 60;                             // 01:00 WIB, menit sejak 00:00
int quietEndMin   = 4 * 60;                             // 04:00 WIB
const float         STABLE_VARIATION_PCT = 0.10f;              // Variasi <= 10%
const float         QUIET_FLOW_THRESHOLD = 1.0f;               // > 1.0 L/menit

// Interval Pengiriman
const unsigned long TELEMETRY_INTERVAL_MS = 10000UL; // 10 detik

// NTP Server
const char* NTP_SERVER1 = "pool.ntp.org";
const char* NTP_SERVER2 = "time.google.com";

// ==========================================
// OBJEK GLOBAL
// ==========================================
WiFiClientSecure espClient;
PubSubClient mqttClient(espClient);
Preferences prefs;

// Topik MQTT (Diformat otomatis sesuai MQTT_DEVICE_ID)
String topicTelemetry;
String topicAlert;
String topicStatus;
String topicCmd;
String topicAck;
String topicConfig;

// Status & Variabel Sistem
volatile unsigned long pulseCount = 0;
unsigned long lastPulseTime = 0;
float currentFlowRateLpm = 0.0f;
float deltaVolumeL = 0.0f;

bool valveIsOpen = true;
uint32_t currentMsgId = 1;
uint32_t lastExecutedCommandId = 0;

// Tracking Deteksi Bocor
unsigned long continuousFlowStartMs = 0;
unsigned long stableFlowStartMs = 0;
float stableBaselineFlow = 0.0f;
unsigned long quietHoursFlowStartMs = 0;

// Timer Loop
unsigned long lastTelemetryMillis = 0;
unsigned long lastFlowCalcMillis = 0;
unsigned long lastWifiCheckMillis = 0;

// Button Debounce
int lastButtonState = HIGH;
unsigned long lastDebounceTime = 0;
const unsigned long DEBOUNCE_DELAY_MS = 50;

// ==========================================
// INTERRUPT SERVICE ROUTINE (FLOW SENSOR)
// ==========================================
void IRAM_ATTR flowSensorISR() {
  pulseCount++;
}

// ==========================================
// HELPER NVS (PREFERENCES)
// ==========================================
uint32_t getNextMsgId() {
  currentMsgId++;
  prefs.putUInt("msg_id", currentMsgId);
  return currentMsgId;
}

void saveValveState(bool isOpen) {
  valveIsOpen = isOpen;
  prefs.putBool("valve_open", valveIsOpen);
}

// ==========================================
// KENDALI FISIK VALVE & LED
// ==========================================
void applyValveState(bool open) {
  valveIsOpen = open;
  if (valveIsOpen) {
    digitalWrite(PIN_RELAY_VALVE, VALVE_OPEN_SIGNAL);
    digitalWrite(PIN_LED_GREEN, HIGH);
    digitalWrite(PIN_LED_RED, LOW);
  } else {
    digitalWrite(PIN_RELAY_VALVE, VALVE_CLOSE_SIGNAL);
    digitalWrite(PIN_LED_GREEN, LOW);
    digitalWrite(PIN_LED_RED, HIGH);
  }
}

// ==========================================
// TIME & ISO 8601 TIMESTAMP HELPER
// ==========================================
bool getNtpTime(char* buffer, size_t maxLen) {
  time_t now;
  struct tm timeinfo;
  time(&now);
  gmtime_r(&now, &timeinfo);

  // Jika tahun < 2026, kemungkinan belum tersinkronisasi NTP
  if (timeinfo.tm_year + 1900 < 2026) {
    return false;
  }

  // Format ISO 8601 UTC: "2026-11-07T07:21:30Z"
  strftime(buffer, maxLen, "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return true;
}

// Menit sejak 00:00 WIB.
int getLocalMinuteOfDayWIB() {
  time_t now;
  struct tm timeinfo;
  time(&now);
  // Tambah offset WIB (UTC+7) = 7 * 3600 detik
  time_t nowWib = now + (7 * 3600);
  gmtime_r(&nowWib, &timeinfo);
  return timeinfo.tm_hour * 60 + timeinfo.tm_min;
}

// Rentang jam sepi boleh melewati tengah malam, mis. 22:00 sampai 05:00.
bool isInQuietHours(int minuteOfDay) {
  if (quietStartMin < quietEndMin) {
    return minuteOfDay >= quietStartMin && minuteOfDay < quietEndMin;
  }
  return minuteOfDay >= quietStartMin || minuteOfDay < quietEndMin;
}

// ==========================================
// PENGIRIMAN PESAN MQTT
// ==========================================
void sendTelemetry() {
  if (!mqttClient.connected()) return;

  char tsBuf[30];
  bool timeValid = getNtpTime(tsBuf, sizeof(tsBuf));

  JsonDocument doc;
  doc["msg_id"] = getNextMsgId();
  if (timeValid) {
    doc["ts"] = tsBuf;
  } else {
    doc["ts"] = nullptr;
  }
  doc["flow_lpm"] = serialized(String(currentFlowRateLpm, 2));
  doc["volume_l_delta"] = serialized(String(deltaVolumeL, 3));
  doc["valve"] = valveIsOpen ? "OPEN" : "CLOSED";

  char jsonBuffer[256];
  serializeJson(doc, jsonBuffer);
  mqttClient.publish(topicTelemetry.c_str(), jsonBuffer, false);

  // Reset delta volume setelah dipublish
  deltaVolumeL = 0.0f;
}

void sendAlert(const char* ruleName) {
  // Sesuai PRD: valve langsung ditutup seketika oleh ESP32 sebelum kirim alert
  applyValveState(false);
  saveValveState(false);

  if (!mqttClient.connected()) return;

  char tsBuf[30];
  bool timeValid = getNtpTime(tsBuf, sizeof(tsBuf));

  JsonDocument doc;
  doc["msg_id"] = getNextMsgId();
  if (timeValid) {
    doc["ts"] = tsBuf;
  } else {
    doc["ts"] = nullptr;
  }
  doc["rule"] = ruleName;
  doc["flow_lpm"] = serialized(String(currentFlowRateLpm, 2));
  doc["valve"] = "CLOSED";

  char jsonBuffer[256];
  serializeJson(doc, jsonBuffer);
  mqttClient.publish(topicAlert.c_str(), jsonBuffer, false);
}

void sendStatus(const char* source) {
  if (!mqttClient.connected()) return;

  char tsBuf[30];
  bool timeValid = getNtpTime(tsBuf, sizeof(tsBuf));

  JsonDocument doc;
  doc["msg_id"] = getNextMsgId();
  if (timeValid) {
    doc["ts"] = tsBuf;
  } else {
    doc["ts"] = nullptr;
  }
  doc["valve"] = valveIsOpen ? "OPEN" : "CLOSED";
  doc["source"] = source; // "BOOT" atau "MANUAL_BUTTON"

  char jsonBuffer[256];
  serializeJson(doc, jsonBuffer);
  mqttClient.publish(topicStatus.c_str(), jsonBuffer, false);
}

void sendAck(uint32_t cmdId, const char* result) {
  if (!mqttClient.connected()) return;

  JsonDocument doc;
  doc["command_id"] = cmdId;
  doc["result"] = result; // "OK" atau "ERROR"
  doc["valve"] = valveIsOpen ? "OPEN" : "CLOSED";

  char jsonBuffer[256];
  serializeJson(doc, jsonBuffer);
  mqttClient.publish(topicAck.c_str(), jsonBuffer, false);
}

// ==========================================
// AMBANG PER KAMAR DARI APLIKASI (CONTRACT.md 2.10)
// ==========================================
// "HH:MM" menjadi menit sejak 00:00. -1 bila formatnya salah.
int parseMinuteOfDay(const char* text) {
  int hour = -1;
  int minute = -1;
  if (sscanf(text, "%d:%d", &hour, &minute) != 2) return -1;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return -1;
  return hour * 60 + minute;
}

void applyRuleConfig(byte* payload, unsigned int length) {
  JsonDocument doc;
  if (deserializeJson(doc, payload, length)) return;

  unsigned long continuousSec = doc["continuous_sec"] | 0UL;
  unsigned long stableSec = doc["stable_sec"] | 0UL;
  unsigned long quietSec = doc["quiet_sec"] | 0UL;
  int quietStart = parseMinuteOfDay(doc["quiet_start"] | "");
  int quietEnd = parseMinuteOfDay(doc["quiet_end"] | "");
  if (quietStart < 0 || quietEnd < 0 || quietStart == quietEnd) return;

  const unsigned long minSec = 1UL;
  const unsigned long maxSec = 86400UL;
  if (continuousSec < minSec || continuousSec > maxSec ||
      stableSec < minSec || stableSec > maxSec ||
      quietSec < minSec || quietSec > maxSec) {
    return;
  }

  continuousLeakMs = continuousSec * 1000UL;
  stableLeakMs = stableSec * 1000UL;
  quietLeakMs = quietSec * 1000UL;
  prefs.putULong("cont_ms", continuousLeakMs);
  prefs.putULong("stab_ms", stableLeakMs);
  prefs.putULong("quiet_ms", quietLeakMs);
  quietStartMin = quietStart;
  quietEndMin = quietEnd;
  prefs.putInt("quiet_start", quietStartMin);
  prefs.putInt("quiet_end", quietEndMin);

  // Hitung ulang dari awal supaya ambang baru berlaku penuh.
  continuousFlowStartMs = 0;
  stableFlowStartMs = 0;
  quietHoursFlowStartMs = 0;
}

// ==========================================
// MQTT CALLBACK (MENERIMA CMD DARI APLIKASI)
// ==========================================
void onMqttMessage(char* topic, byte* payload, unsigned int length) {
  if (String(topic) == topicConfig) {
    applyRuleConfig(payload, length);
    return;
  }
  if (String(topic) != topicCmd) return;

  JsonDocument doc;
  DeserializationError error = deserializeJson(doc, payload, length);
  if (error) {
    return;
  }

  uint32_t cmdId = doc["command_id"] | 0;
  const char* action = doc["action"] | "";

  // Kontrak 2.5: Abaikan command_id yang sudah pernah dieksekusi, tapi tetap kirim ack
  if (cmdId == lastExecutedCommandId && cmdId != 0) {
    sendAck(cmdId, "OK");
    return;
  }

  if (strcmp(action, "OPEN") == 0) {
    applyValveState(true);
    saveValveState(true);
    lastExecutedCommandId = cmdId;
    prefs.putUInt("last_cmd", lastExecutedCommandId);
    sendAck(cmdId, "OK");
  } else if (strcmp(action, "CLOSE") == 0) {
    applyValveState(false);
    saveValveState(false);
    lastExecutedCommandId = cmdId;
    prefs.putUInt("last_cmd", lastExecutedCommandId);
    sendAck(cmdId, "OK");
  } else {
    sendAck(cmdId, "ERROR");
  }
}

// ==========================================
// ATURAN DETEKSI KEBOCORAN LOKAL
// ==========================================
void checkLeakRules(unsigned long now) {
  // Hanya evaluasi kebocoran jika valve sedang OPEN
  if (!valveIsOpen) {
    continuousFlowStartMs = 0;
    stableFlowStartMs = 0;
    quietHoursFlowStartMs = 0;
    return;
  }

  // 1. Aliran Kontinu (CONTINUOUS): flow > 0 tanpa henti selama 45 menit
  if (currentFlowRateLpm > 0.1f) {
    if (continuousFlowStartMs == 0) {
      continuousFlowStartMs = now;
    } else if (now - continuousFlowStartMs >= continuousLeakMs) {
      sendAlert("CONTINUOUS");
      continuousFlowStartMs = 0;
      return;
    }
  } else {
    continuousFlowStartMs = 0;
  }

  // 2. Aliran Stabil (STABLE): variasi flow <= +-10% selama >= 5 menit
  if (currentFlowRateLpm > 0.2f) {
    if (stableFlowStartMs == 0) {
      stableFlowStartMs = now;
      stableBaselineFlow = currentFlowRateLpm;
    } else {
      float diff = abs(currentFlowRateLpm - stableBaselineFlow);
      if (diff / stableBaselineFlow <= STABLE_VARIATION_PCT) {
        if (now - stableFlowStartMs >= stableLeakMs) {
          sendAlert("STABLE");
          stableFlowStartMs = 0;
          return;
        }
      } else {
        // Reset baseline jika terjadi lonjakan/perubahan variasi
        stableFlowStartMs = now;
        stableBaselineFlow = currentFlowRateLpm;
      }
    }
  } else {
    stableFlowStartMs = 0;
  }

  // 3. Aliran Jam Sepi (QUIET_HOURS): flow > 1.0 L/menit melewati batas pada rentang jam sepi kamar
  char dummyBuf[30];
  if (getNtpTime(dummyBuf, sizeof(dummyBuf))) {
    bool isQuietHours = isInQuietHours(getLocalMinuteOfDayWIB());

    if (isQuietHours && currentFlowRateLpm >= QUIET_FLOW_THRESHOLD) {
      if (quietHoursFlowStartMs == 0) {
        quietHoursFlowStartMs = now;
      } else if (now - quietHoursFlowStartMs >= quietLeakMs) {
        sendAlert("QUIET_HOURS");
        quietHoursFlowStartMs = 0;
        return;
      }
    } else {
      quietHoursFlowStartMs = 0;
    }
  }
}

// ==========================================
// HANDLING TOMBOL FISIK
// ==========================================
void handleButton() {
  int reading = digitalRead(PIN_BUTTON_MANUAL);

  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }

  if ((millis() - lastDebounceTime) > DEBOUNCE_DELAY_MS) {
    // Tombol tipe active-low (ditekan = LOW)
    if (reading == LOW && !valveIsOpen) {
      // Tekan 1x -> Membuka valve
      applyValveState(true);
      saveValveState(true);
      sendStatus("MANUAL_BUTTON");
    }
  }

  lastButtonState = reading;
}

// ==========================================
// KONEKSI WIFI & MQTT (TLS)
// ==========================================
void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;

  WiFi.mode(WIFI_STA);
  // Modem sleep bisa menunda paket dan memutus koneksi MQTT.
  WiFi.setSleep(false);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long startAttempt = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startAttempt < 15000) {
    digitalWrite(PIN_LED_BLUE, !digitalRead(PIN_LED_BLUE)); // Kedip cepat saat mencoba konek
    delay(300);
  }

  if (WiFi.status() == WL_CONNECTED) {
    digitalWrite(PIN_LED_BLUE, HIGH); // Biru menyala jika WiFi terhubung
    configTime(0, 0, NTP_SERVER1, NTP_SERVER2); // Sync NTP (UTC)
  } else {
    digitalWrite(PIN_LED_BLUE, LOW);
  }
}

void connectMqtt() {
  if (WiFi.status() != WL_CONNECTED) return;
  if (mqttClient.connected()) return;

  // Set TLS CA Certificate (Strict: AGENTS.md larang setInsecure)
  espClient.setCACert(MQTT_CA_CERT);

  String clientId = "ESP32_SWM_" + String(MQTT_DEVICE_ID) + "_" + String(random(0xffff), HEX);
  if (mqttClient.connect(clientId.c_str(), MQTT_USERNAME, MQTT_PASSWORD)) {
    mqttClient.subscribe(topicCmd.c_str(), 1); // QoS 1
    mqttClient.subscribe(topicConfig.c_str(), 1); // Retained: diterima lagi setiap tersambung
    digitalWrite(PIN_LED_BLUE, HIGH);
  } else {
    digitalWrite(PIN_LED_BLUE, LOW);
  }
}

// ==========================================
// SETUP
// ==========================================
void setup() {
  Serial.begin(115200);

  // Inisialisasi GPIO
  pinMode(PIN_FLOW_SENSOR, INPUT_PULLUP);
  pinMode(PIN_BUTTON_MANUAL, INPUT_PULLUP);
  pinMode(PIN_RELAY_VALVE, OUTPUT);
  pinMode(PIN_LED_RED, OUTPUT);
  pinMode(PIN_LED_GREEN, OUTPUT);
  pinMode(PIN_LED_BLUE, OUTPUT);

  // Interrupt sensor debit air
  attachInterrupt(digitalPinToInterrupt(PIN_FLOW_SENSOR), flowSensorISR, RISING);

  // Load state dari NVS
  prefs.begin("smart_water", false);
  currentMsgId = prefs.getUInt("msg_id", 0);
  lastExecutedCommandId = prefs.getUInt("last_cmd", 0);
  // Default pertama kali = true (Normaly Closed valve standby terbuka saat normal)
  valveIsOpen = prefs.getBool("valve_open", true);

  // Ambang kamar terakhir dari aplikasi
  continuousLeakMs = prefs.getULong("cont_ms", continuousLeakMs);
  stableLeakMs = prefs.getULong("stab_ms", stableLeakMs);
  quietLeakMs = prefs.getULong("quiet_ms", quietLeakMs);
  quietStartMin = prefs.getInt("quiet_start", quietStartMin);
  quietEndMin = prefs.getInt("quiet_end", quietEndMin);

  // Terapkan status valve hasil restore NVS
  applyValveState(valveIsOpen);

  // Format String topik MQTT
  topicTelemetry = "swm/" + String(MQTT_DEVICE_ID) + "/telemetry";
  topicAlert     = "swm/" + String(MQTT_DEVICE_ID) + "/alert";
  topicStatus    = "swm/" + String(MQTT_DEVICE_ID) + "/status";
  topicCmd       = "swm/" + String(MQTT_DEVICE_ID) + "/cmd";
  topicAck       = "swm/" + String(MQTT_DEVICE_ID) + "/ack";
  topicConfig    = "swm/" + String(MQTT_DEVICE_ID) + "/config";

  // Konfigurasi MQTT Client
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(onMqttMessage);
  mqttClient.setBufferSize(512);
  // Beri ruang untuk gangguan Wi-Fi sesaat (default PubSubClient 15 detik).
  mqttClient.setKeepAlive(60);

  // Sambungkan WiFi & MQTT
  connectWiFi();
  connectMqtt();

  // CONTRACT.md 2.6: Setelah boot, kirim status dengan source: BOOT
  sendStatus("BOOT");
}

// ==========================================
// MAIN LOOP
// ==========================================
void loop() {
  unsigned long now = millis();

  // 1. Cek & Tangani Koneksi
  if (WiFi.status() != WL_CONNECTED) {
    if (now - lastWifiCheckMillis >= 5000) {
      lastWifiCheckMillis = now;
      connectWiFi();
    }
  } else {
    if (!mqttClient.connected()) {
      if (now - lastWifiCheckMillis >= 5000) {
        lastWifiCheckMillis = now;
        connectMqtt();
      }
    } else {
      mqttClient.loop();
    }
  }

  // 2. Baca Tombol Fisik (Debounced)
  handleButton();

  // 3. Kalkulasi Debit & Volume Tiap 1 Detik
  if (now - lastFlowCalcMillis >= 1000) {
    detachInterrupt(digitalPinToInterrupt(PIN_FLOW_SENSOR));
    unsigned long pulses = pulseCount;
    pulseCount = 0;
    attachInterrupt(digitalPinToInterrupt(PIN_FLOW_SENSOR), flowSensorISR, RISING);

    float secondsElapsed = (now - lastFlowCalcMillis) / 1000.0f;
    lastFlowCalcMillis = now;

    // L/menit = (pulsa / detik) / 7.5
    currentFlowRateLpm = (pulses / secondsElapsed) / FLOW_CALIBRATION_FACTOR;

    // Volume = debit (L/menit) * (detik / 60)
    float volumeCurrentSecond = currentFlowRateLpm * (secondsElapsed / 60.0f);
    deltaVolumeL += volumeCurrentSecond;

    // Evaluasi Aturan Kebocoran Lokal
    checkLeakRules(now);
  }

  // 4. Publikasi Telemetri Tiap 10 Detik
  if (now - lastTelemetryMillis >= TELEMETRY_INTERVAL_MS) {
    lastTelemetryMillis = now;
    sendTelemetry();
  }
}
