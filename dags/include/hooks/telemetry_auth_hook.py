from airflow.hooks.base import BaseHook
import requests
import logging


class TelemetryAuthHook(BaseHook):
    """
    Hook for managing authentication with the Telemetry Vendor API.
    Handles token retrieval and automatic refresh.
    """

    conn_id_attribute = "telemetry_conn_id"
    default_conn_name = "telemetry_api_auth"
    conn_type = "generic"
    hook_name = "Telemetry API Auth"

    def __init__(self, telemetry_conn_id: str = default_conn_name, **kwargs):
        super().__init__(**kwargs)
        self.telemetry_conn_id = telemetry_conn_id
        self.token = None
        self.host = None
        self.client_id = None
        self.client_secret = None

    def _get_connection_details(self):
        conn = self.get_connection(self.telemetry_conn_id)
        self.host = conn.host
        if not self.host.startswith("http"):
            self.host = f"http://{self.host}"
        self.client_id = conn.login
        self.client_secret = conn.password

    def _authenticate(self):
        """Fetches a new Bearer token."""
        if not self.host:
            self._get_connection_details()

        url = f"{self.host.rstrip('/')}/v1/oauth/token"
        logging.info(f"Authenticating with {url} using Client ID: {self.client_id}")

        response = requests.post(
            url,
            json={"client_id": self.client_id, "client_secret": self.client_secret},
            timeout=10,
        )

        if response.status_code == 200:
            data = response.json()
            self.token = data.get("access_token")
            logging.info("Successfully retrieved Bearer token.")
        else:
            logging.error(
                f"Authentication failed: {response.status_code} - {response.text}"
            )
            response.raise_for_status()

    def get_headers(self):
        """Returns headers with a valid Bearer token."""
        if not self.token:
            self._authenticate()

        return {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        }

    def refresh_token_if_needed(self, status_code: int):
        """Refreshes token if a 401 is encountered."""
        if status_code == 401:
            logging.info("Token expired (401). Refreshing...")
            self._authenticate()
            return True
        return False
