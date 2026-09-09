"""Serve build/app/outputs/bundle/release with CORS for Play Console upload."""
from __future__ import annotations

import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    'tool',
    'out',
    'aab',
)
PORT = 8766


class CORS(SimpleHTTPRequestHandler):
  def end_headers(self) -> None:
    self.send_header('Access-Control-Allow-Origin', '*')
    self.send_header('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
    self.send_header('Access-Control-Allow-Headers', '*')
    super().end_headers()

  def do_OPTIONS(self) -> None:  # noqa: N802
    self.send_response(204)
    self.end_headers()


def main() -> None:
  os.chdir(ROOT)
  print(f'serving {ROOT} on :{PORT}', flush=True)
  ThreadingHTTPServer(('127.0.0.1', PORT), CORS).serve_forever()


if __name__ == '__main__':
  main()
