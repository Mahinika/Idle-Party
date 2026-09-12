"""CORS static server for Play Console listing uploads."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
import traceback

ROOT = os.path.dirname(os.path.abspath(__file__))
os.chdir(ROOT)


class CORS(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        print("[%s] %s" % (self.log_date_time_string(), fmt % args), flush=True)

    def handle_one_request(self):
        try:
            super().handle_one_request()
        except Exception:
            traceback.print_exc()

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    port = 9888
    print("serving", ROOT, "on 127.0.0.1:%s" % port, flush=True)
    ThreadingHTTPServer(("127.0.0.1", port), CORS).serve_forever()
