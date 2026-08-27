"""Serve release AAB with CORS for Play Console browser upload."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import os

ROOT = os.path.join(
    os.path.dirname(__file__),
    "..",
    "build",
    "app",
    "outputs",
    "bundle",
    "release",
)


class CORSHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    os.chdir(ROOT)
    print(f"Serving {ROOT} on http://127.0.0.1:8765/")
    ThreadingHTTPServer(("127.0.0.1", 8765), CORSHandler).serve_forever()
