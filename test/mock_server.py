"""Servidor falso da API SmartThings para testar o widget sem conta nem dispositivos."""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


def cap(**attrs):
    return {name: {"value": value} for name, value in attrs.items()}


DEVICES = {
    "ac-1": ("Ar da sala", {
        "switch": cap(switch="on"),
        "temperatureMeasurement": cap(temperature=23),
        "thermostatCoolingSetpoint": cap(coolingSetpoint=23, coolingSetpointRange={"minimum": 16, "maximum": 30}),
        "airConditionerMode": cap(airConditionerMode="cool", supportedAcModes=["auto", "cool", "dry", "wind", "heat"]),
        "airConditionerFanMode": cap(fanMode="auto", supportedAcFanModes=["auto", "low", "medium", "high", "turbo"]),
        "custom.airConditionerOptionalMode": cap(acOptionalMode="off", supportedAcOptionalMode=["off", "sleep", "quiet", "windFree"]),
        "fanOscillationMode": cap(fanOscillationMode="vertical", supportedFanOscillationModes=["fixed", "vertical", "horizontal", "all"]),
    }),
    "light-1": ("Luz do quarto", {
        "switch": cap(switch="on"),
        "switchLevel": cap(level=70),
        "colorTemperature": cap(colorTemperature=4000),
    }),
    "plug-1": ("Tomada da cafeteira", {"switch": cap(switch="off")}),
    "sensor-1": ("Sensor da porta", {"contactSensor": cap(contact="closed")}),
}
VALID_TOKEN = "access-2"
ATTRIBUTE_FOR = {
    "setCoolingSetpoint": "coolingSetpoint", "setLevel": "level", "setColorTemperature": "colorTemperature",
    "setAirConditionerMode": "airConditionerMode", "setFanMode": "fanMode",
    "setAcOptionalMode": "acOptionalMode", "setFanOscillationMode": "fanOscillationMode",
}


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass

    def authorized(self):
        ok = self.headers.get("Authorization") == "Bearer " + VALID_TOKEN
        if not ok:
            print("401", self.command, self.path, flush=True)
            self.reply(401, {"error": "unauthorized"})
        return ok

    def do_GET(self):
        if not self.authorized():
            return
        parts = self.path.strip("/").split("/")
        if parts == ["v1", "devices"]:
            print("GET devices", flush=True)
            self.reply(200, {"items": [
                {"deviceId": did, "label": label,
                 "components": [{"id": "main", "capabilities": [{"id": c} for c in status]}]}
                for did, (label, status) in DEVICES.items()]})
        elif len(parts) == 6 and parts[5] == "status" and parts[2] in DEVICES:
            self.reply(200, DEVICES[parts[2]][1])
        else:
            self.reply(404, {})

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode()
        if self.path == "/oauth/token":
            print("TOKEN", self.headers.get("Authorization"), body, flush=True)
            self.reply(200, {"access_token": VALID_TOKEN, "refresh_token": "refresh-2", "expires_in": 86400})
            return
        if not self.authorized():
            return
        device_id = self.path.strip("/").split("/")[2]
        status = DEVICES[device_id][1]
        for c in json.loads(body)["commands"]:
            print("COMMAND", device_id, c["capability"], c["command"], c["arguments"], flush=True)
            if c["command"] in ("on", "off"):
                status["switch"]["switch"]["value"] = c["command"]
            else:
                status[c["capability"]][ATTRIBUTE_FOR[c["command"]]]["value"] = c["arguments"][0]
        self.reply(200, {"results": [{"status": "ACCEPTED"}]})


HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
