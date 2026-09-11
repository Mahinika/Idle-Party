from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import os

os.chdir(r"D:\Projects\Personal\idle party\Idle-Party\tool\store_listing\upload")


class CORS(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()


ThreadingHTTPServer(("127.0.0.1", 9877), CORS).serve_forever()
