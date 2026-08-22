"""CORS HTTP server for Play Console AAB upload (fetch + DataTransfer)."""
from __future__ import annotations

import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "build" / "app" / "outputs" / "bundle" / "release"


class CORSHandler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        super().end_headers()

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.end_headers()


def main() -> None:
    os.chdir(ROOT)
    print(f"Serving {ROOT} on http://127.0.0.1:8765/")
    ThreadingHTTPServer(("127.0.0.1", 8765), CORSHandler).serve_forever()


if __name__ == "__main__":
    main()
