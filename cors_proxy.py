from http.server import BaseHTTPRequestHandler
from http.server import ThreadingHTTPServer
import urllib.request
import urllib.parse

class ProxyHTTPRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        query = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(query)
        if 'url' in params:
            target_url = params['url'][0]
            try:
                req = urllib.request.Request(target_url, headers={
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
                    'Accept-Language': 'en-US,en;q=0.9',
                })
                with urllib.request.urlopen(req, timeout=5) as response:
                    self.send_response(response.getcode())
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.send_header('Content-Type', response.headers.get('Content-Type', 'image/jpeg'))
                    self.end_headers()
                    self.wfile.write(response.read())
            except Exception as e:
                print(f"Error fetching {target_url}: {e}")
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode())
        else:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"Missing url parameter")

if __name__ == '__main__':
    server_address = ('0.0.0.0', 8081)
    httpd = ThreadingHTTPServer(server_address, ProxyHTTPRequestHandler)
    print('Starting threaded CORS proxy on port 8081...')
    httpd.serve_forever()
