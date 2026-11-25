"""Loopback transport fixture for browser tests. Contacts only the Auth emulator."""
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.request import Request, urlopen
from urllib.error import HTTPError

AUTH = "http://127.0.0.1:8610/identitytoolkit.googleapis.com/v1/accounts:lookup?key=emulator-only"
ORIGIN = "http://127.0.0.1:8613"


class Fixture(BaseHTTPRequestHandler):
    def _headers(self, status, mime):
        self.send_response(status)
        self.send_header("Content-Type", mime)
        if self.headers.get("Origin") == ORIGIN:
            self.send_header("Access-Control-Allow-Origin", ORIGIN)
        self.send_header("Access-Control-Expose-Headers", "Retry-After")

    def _json(self, status, body):
        self._headers(status, "application/json")
        if status == 429:
            self.send_header("Retry-After", "7")
        self.end_headers()
        self.wfile.write(json.dumps(body).encode())

    def do_GET(self):
        self._json(200, {"status": "ok"}) if self.path == "/health" else self._json(404, {})

    def do_OPTIONS(self):
        self._headers(204, "application/json")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.end_headers()

    def do_POST(self):
        if self.path != "/api/chat/completions":
            self._json(404, {})
            return
        authorization = self.headers.get("Authorization", "").removeprefix("Bearer ")
        try:
            request = Request(AUTH, data=json.dumps({"idToken": authorization}).encode(),
                              headers={"Content-Type": "application/json"})
            with urlopen(request, timeout=5) as response:
                if not json.load(response).get("users"):
                    self._json(401, {"error": "no user"})
                    return
        except HTTPError:
            self._json(401, {"error": "invalid session"})
            return
        message = json.loads(self.rfile.read(int(self.headers["Content-Length"])))["messages"][-1]["content"]
        if message in ("fixture-401", "fixture-429"):
            self._json(int(message[-3:]), {"error": "fixture response"})
            return
        self._headers(200, "text/event-stream")
        self.end_headers()
        try:
            for chunk in ["Қазақша: бірінші бөлік. ", "Русский: вторая часть."]:
                event = json.dumps({"choices": [{"delta": {"content": chunk}}]}, ensure_ascii=False)
                self.wfile.write(f"data: {event}\n\n".encode())
                self.wfile.flush()
                time.sleep(2)
            self.wfile.write(b"data: [DONE]\n\n")
        except (BrokenPipeError, ConnectionResetError):
            pass


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8612), Fixture).serve_forever()
