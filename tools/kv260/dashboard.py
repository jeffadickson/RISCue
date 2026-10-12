#!/usr/bin/env python3
"""Local lab dashboard; one process exclusively owns the chosen UIO device."""
import argparse,json
from pathlib import Path
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from riscue_ctl import RISCue
ROOT=Path(__file__).resolve().parents[2]
def main():
    p=argparse.ArgumentParser();p.add_argument('--device',default='/dev/uio0');p.add_argument('--bind',default='127.0.0.1');p.add_argument('--port',type=int,default=8080);a=p.parse_args();device=RISCue(a.device)
    class Handler(BaseHTTPRequestHandler):
        def reply(self,value,status=200):
            data=json.dumps(value).encode();self.send_response(status);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
        def do_GET(self):
            try:
                if self.path=='/api/status':
                    with device.lock:self.reply(device.status())
                elif self.path=='/':
                    data=(ROOT/'boards/kv260/dashboard.html').read_bytes();self.send_response(200);self.send_header('Content-Type','text/html; charset=utf-8');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
                else:self.reply({'error':'Not found'},404)
            except Exception as e:self.reply({'error':str(e)},400)
        def do_POST(self):
            try:
                # Browser access is same-origin; no cross-origin control endpoint.
                origin=self.headers.get('Origin');host=self.headers.get('Host')
                if origin and origin not in ('http://'+host,'https://'+host):raise ValueError('Cross-origin control rejected')
                size=int(self.headers.get('Content-Length','0'))
                if not 0<size<=262144:raise ValueError('Invalid request size')
                raw=self.rfile.read(size)
                with device.lock:
                    if self.path=='/api/load':out=device.load(raw)
                    else:
                        body=json.loads(raw)
                        if self.path=='/api/control':device.run() if body.get('run') else device.stop();out=device.status()
                        elif self.path=='/api/irq':device.irq(bool(body.get('asserted')));out=device.status()
                        elif self.path=='/api/inject':out=device.inject(**body)
                        elif self.path=='/api/mailbox':out=device.mailbox()
                        else:self.reply({'error':'Not found'},404);return
                self.reply(out)
            except Exception as e:self.reply({'error':str(e)},400)
    server=ThreadingHTTPServer((a.bind,a.port),Handler);print(f'RISCue lab dashboard: http://{a.bind}:{a.port}')
    try:server.serve_forever()
    finally:server.server_close();device.close()
if __name__=='__main__':main()
