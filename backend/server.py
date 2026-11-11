from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import re
import time

tanks = [
    {
        "Device_id": "tank_001",
        "tankCapacity": 25000.0,
        "tankHeight": 2500.0,
        "tankShape": "cylindrical",
        "VREF": 3300.0,
        "CORRECTION_FACTOR": 1.41,
        "OFFSET": 0.0
    },
    {
        "Device_id": "tank_002",
        "tankCapacity": 10000.0,
        "tankHeight": 4000.0,
        "tankShape": "cylindrical",
        "VREF": 3300.0,
        "CORRECTION_FACTOR": 1.41,
        "OFFSET": 0.0
    }
]

telemetries = {
    "tank_001": {
        "Device_id": "tank_001",
        "waterPercent": 75.0,
        "depth": 1.875,
        "rawADC": 3072.0,
        "dataVoltage": 3300.0,
        "dataCurrent": 4.0,
        "timestamp": int(time.time())
    },
    "tank_002": {
        "Device_id": "tank_002",
        "waterPercent": 88.0,
        "depth": 3.52,
        "rawADC": 3603.0,
        "dataVoltage": 3300.0,
        "dataCurrent": 4.0,
        "timestamp": int(time.time())
    }
}

history = {
    "tank_001": [
        {
            "Device_id": "tank_001",
            "waterPercent": "75.0",
            "depth": "1.875",
            "rawADC": "3072",
            "dataVoltage": "3300",
            "dataCurrent": "4.0",
            "timestamp": str(int(time.time()))
        }
    ]
}

class RequestHandler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        path = self.path
        
        # 1. GET /prod/tanks
        if path == '/prod/tanks':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(tanks).encode('utf-8'))
            return
            
        # 2. GET /prod/tank/{deviceId}/latest
        latest_match = re.match(r'^/prod/tank/([^/]+)/latest$', path)
        if latest_match:
            device_id = latest_match.group(1)
            if device_id in telemetries:
                data = telemetries[device_id].copy()
                data['timestamp'] = int(time.time())
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self._send_cors_headers()
                self.end_headers()
                self.wfile.write(json.dumps(data).encode('utf-8'))
            else:
                self.send_response(404)
                self._send_cors_headers()
                self.end_headers()
            return

        # 3. GET /prod/tank/{deviceId}/history
        history_match = re.match(r'^/prod/tank/([^/]+)/history$', path)
        if history_match:
            device_id = history_match.group(1)
            data = history.get(device_id, [])
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(data).encode('utf-8'))
            return

        # 4. GET /prod/tank/{deviceId}/config
        config_match = re.match(r'^/prod/tank/([^/]+)/config$', path)
        if config_match:
            device_id = config_match.group(1)
            config = next((t for t in tanks if t["Device_id"] == device_id), None)
            if config:
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self._send_cors_headers()
                self.end_headers()
                self.wfile.write(json.dumps(config).encode('utf-8'))
            else:
                self.send_response(404)
                self._send_cors_headers()
                self.end_headers()
            return

        self.send_response(404)
        self._send_cors_headers()
        self.end_headers()

    def do_POST(self):
        path = self.path
        
        # 1. POST /prod/tank
        if path == '/prod/tank':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            try:
                new_config = json.loads(post_data.decode('utf-8'))
            except Exception:
                self.send_response(400)
                self._send_cors_headers()
                self.end_headers()
                return

            device_id = new_config.get('Device_id')
            if not device_id:
                self.send_response(400)
                self._send_cors_headers()
                self.end_headers()
                return

            exists = any(t['Device_id'] == device_id for t in tanks)
            if exists:
                self.send_response(409)
                self.send_header('Content-Type', 'application/json')
                self._send_cors_headers()
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Conflict: Tank already exists"}).encode('utf-8'))
                return

            tanks.append({
                "Device_id": device_id,
                "tankCapacity": float(new_config.get("tankCapacity", 15000)),
                "tankHeight": float(new_config.get("tankHeight", 5000)),
                "tankShape": new_config.get("tankShape", "cylindrical"),
                "VREF": float(new_config.get("VREF", 3300.0)),
                "CORRECTION_FACTOR": float(new_config.get("CORRECTION_FACTOR", 1.0)),
                "OFFSET": float(new_config.get("OFFSET", 0.0))
            })

            telemetries[device_id] = {
                "Device_id": device_id,
                "waterPercent": 0.0,
                "depth": 0.0,
                "rawADC": 0.0,
                "dataVoltage": 0.0,
                "dataCurrent": 0.0,
                "timestamp": int(time.time())
            }
            history[device_id] = []

            self.send_response(201)
            self.send_header('Content-Type', 'application/json')
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({
                "message": "Tank created successfully",
                "Device_id": device_id
            }).encode('utf-8'))
            return

        self.send_response(404)
        self._send_cors_headers()
        self.end_headers()

    def do_PUT(self):
        path = self.path
        
        # 1. PUT /prod/tank/{deviceId}/config
        config_match = re.match(r'^/prod/tank/([^/]+)/config$', path)
        if config_match:
            device_id = config_match.group(1)
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            try:
                updated_config = json.loads(post_data.decode('utf-8'))
            except Exception:
                self.send_response(400)
                self._send_cors_headers()
                self.end_headers()
                return

            index = next((i for i, t in enumerate(tanks) if t["Device_id"] == device_id), -1)
            if index == -1:
                self.send_response(404)
                self._send_cors_headers()
                self.end_headers()
                return

            tanks[index] = {
                "Device_id": device_id,
                "tankCapacity": float(updated_config.get("tankCapacity", tanks[index]["tankCapacity"])),
                "tankHeight": float(updated_config.get("tankHeight", tanks[index]["tankHeight"])),
                "tankShape": updated_config.get("tankShape", tanks[index]["tankShape"]),
                "VREF": float(updated_config.get("VREF", tanks[index]["VREF"])),
                "CORRECTION_FACTOR": float(updated_config.get("CORRECTION_FACTOR", tanks[index]["CORRECTION_FACTOR"])),
                "OFFSET": float(updated_config.get("OFFSET", tanks[index]["OFFSET"]))
            }

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({
                "message": "Configuration updated successfully",
                "Device_id": device_id
            }).encode('utf-8'))
            return

        self.send_response(404)
        self._send_cors_headers()
        self.end_headers()

def run(server_class=HTTPServer, handler_class=RequestHandler, port=3000):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print(f"Server started on http://localhost:{port}")
    httpd.serve_forever()

if __name__ == '__main__':
    run()
