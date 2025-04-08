import http.server
import socketserver
import os
import mimetypes
import logging

# 设置日志
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

PORT = 8000

# 添加更多MIME类型
mimetypes.add_type('image/png', '.png')
mimetypes.add_type('image/jpeg', '.jpg')
mimetypes.add_type('image/jpeg', '.jpeg')
mimetypes.add_type('image/gif', '.gif')

class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # 添加更多CORS相关的头
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type')
        self.send_header('Access-Control-Allow-Credentials', 'true')
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        return super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        logger.debug(f"Received GET request for: {self.path}")
        try:
            # 检查请求的文件是否存在
            file_path = self.translate_path(self.path)
            if os.path.exists(file_path):
                logger.debug(f"File exists: {file_path}")
                return super().do_GET()
            else:
                logger.error(f"File not found: {file_path}")
                self.send_error(404, "File not found")
        except Exception as e:
            logger.error(f"Error handling GET request: {e}")
            self.send_error(500, str(e))

    def guess_type(self, path):
        """重写guess_type方法以支持更多MIME类型"""
        base, ext = os.path.splitext(path)
        if ext in self.extensions_map:
            return self.extensions_map[ext]
        ext = ext.lower()
        if ext in self.extensions_map:
            return self.extensions_map[ext]
        return 'application/octet-stream'

print(f"Starting server at http://localhost:{PORT}")
print("Press Ctrl+C to stop")

# 确保服务器在client目录下运行
current_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(current_dir)
print(f"Server working directory: {current_dir}")
print(f"Assets directory exists: {os.path.exists('assets')}")
print(f"Background image exists: {os.path.exists('assets/background.png')}")

# 允许端口重用
socketserver.TCPServer.allow_reuse_address = True

with socketserver.TCPServer(("", PORT), CORSRequestHandler) as httpd:
    httpd.serve_forever() 