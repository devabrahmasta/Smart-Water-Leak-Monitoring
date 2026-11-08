import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, Optional, Any
import httpx

from app.config import settings

logger = logging.getLogger("smartwater.notify.fcm")


@dataclass
class FCMResponse:
    success: bool
    status_code: int
    error_code: Optional[str] = None
    error_message: Optional[str] = None


class FCMClient:
    """
    Klien pengirim notifikasi Firebase Cloud Messaging (FCM) HTTP v1.
    Mendukung pengiriman real dengan Google OAuth2 Service Account serta mode simulasi/mock untuk testing.
    """

    def __init__(
        self,
        project_id: Optional[str] = None,
        service_account_path: Optional[str] = None,
        dry_run: bool = False,
        mock_sender: Optional[Callable[[str, Dict[str, str]], FCMResponse]] = None,
        client: Optional[httpx.Client] = None,
    ):
        self.project_id = project_id or settings.FCM_PROJECT_ID
        self.service_account_path = Path(service_account_path or settings.FCM_SERVICE_ACCOUNT_PATH)
        self.dry_run = dry_run
        self.mock_sender = mock_sender
        self.client = client or httpx.Client(timeout=3.0)

    def _get_access_token(self) -> Optional[str]:
        """
        Mengambil Google OAuth2 access token jika file service-account.json tersedia.
        """
        if not self.service_account_path.exists():
            return None

        try:
            from google.oauth2 import service_account
            import google.auth.transport.requests

            scopes = ["https://www.googleapis.com/auth/firebase.messaging"]
            credentials = service_account.Credentials.from_service_account_file(
                str(self.service_account_path), scopes=scopes
            )
            request = google.auth.transport.requests.Request()
            credentials.refresh(request)
            return credentials.token
        except Exception as e:
            logger.warning(f"Gagal memperoleh access token Google OAuth2 dari service account: {e}")
            return None

    def send_message(self, token: str, data: Dict[str, str]) -> FCMResponse:
        """
        Mengirim pesan data ke satu FCM registration token.
        Semua entri dalam data wajib berupa string murni sesuai FCM HTTP v1.
        """
        if not token:
            return FCMResponse(
                success=False,
                status_code=400,
                error_code="INVALID_ARGUMENT",
                error_message="Token tidak boleh kosong",
            )

        # Validasi kontrak: semua value data harus berupa string
        for k, v in data.items():
            if not isinstance(k, str) or not isinstance(v, str):
                return FCMResponse(
                    success=False,
                    status_code=422,
                    error_code="INVALID_PAYLOAD",
                    error_message=f"Key '{k}' dan value '{v}' harus berupa string",
                )

        # Jika ada handler mock custom (untuk unit test)
        if self.mock_sender is not None:
            return self.mock_sender(token, data)

        # Jika mode dry-run aktif atau service account tidak ada di sistem lokal
        if self.dry_run or not self.service_account_path.exists():
            logger.debug(f"[FCM Dry-Run/Mock] Berhasil mengirim ke {token[:10]}...: {data.get('title')}")
            return FCMResponse(success=True, status_code=200)

        # Mode Real HTTP v1
        access_token = self._get_access_token()
        if not access_token:
            return FCMResponse(
                success=False,
                status_code=401,
                error_code="AUTH_ERROR",
                error_message="Kredensial FCM service account tidak valid atau tidak dapat diakses",
            )

        url = f"https://fcm.googleapis.com/v1/projects/{self.project_id}/messages:send"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json; UTF-8",
        }
        body = {
            "message": {
                "token": token,
                "data": data,
            }
        }

        try:
            resp = self.client.post(url, headers=headers, json=body)
            if resp.status_code == 200:
                return FCMResponse(success=True, status_code=200)

            # Analisis error code dari FCM HTTP v1
            error_code = "UNKNOWN_ERROR"
            err_msg = resp.text
            try:
                err_json = resp.json()
                details = err_json.get("error", {}).get("details", [])
                for d in details:
                    if d.get("@type") == "type.googleapis.com/google.firebase.fcm.v1.FcmError":
                        error_code = d.get("errorCode", error_code)
                if error_code == "UNKNOWN_ERROR":
                    status = err_json.get("error", {}).get("status", "")
                    if status in ("NOT_FOUND", "UNREGISTERED"):
                        error_code = "UNREGISTERED"
            except Exception:
                pass

            if "UNREGISTERED" in err_msg or "NOT_FOUND" in err_msg or resp.status_code == 404:
                error_code = "UNREGISTERED"

            return FCMResponse(
                success=False,
                status_code=resp.status_code,
                error_code=error_code,
                error_message=err_msg,
            )
        except Exception as e:
            logger.error(f"Pengecualian saat menghubungi FCM HTTP v1: {e}")
            return FCMResponse(
                success=False,
                status_code=500,
                error_code="NETWORK_ERROR",
                error_message=str(e),
            )
