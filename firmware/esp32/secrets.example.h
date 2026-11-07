// Salin menjadi secrets.h lalu isi. secrets.h tidak boleh di-commit.
#pragma once

#define WIFI_SSID      ""
#define WIFI_PASSWORD  ""

#define MQTT_HOST      ""
#define MQTT_PORT      8883
#define MQTT_DEVICE_ID "1"
#define MQTT_USERNAME  ""
#define MQTT_PASSWORD  ""

// Isi dengan CA broker (PEM), dipakai oleh setCACert().
static const char MQTT_CA_CERT[] = R"EOF(
-----BEGIN CERTIFICATE-----
-----END CERTIFICATE-----
)EOF";
