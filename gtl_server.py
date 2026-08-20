import socket
import json

# GTL Configuration
HOST = '0.0.0.0'
PORT = 5000
TOTAL_TOKENS = 2  # The safe injection limit (only allow 2 bursts at a time)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((HOST, PORT))

print(f"[*] ViYouna GTL Server running on {HOST}:{PORT}")
print(f"[*] Total Fabric Tokens: {TOTAL_TOKENS}")

available_tokens = TOTAL_TOKENS

while True:
    data, addr = sock.recvfrom(1024)
    request = json.loads(data.decode('utf-8'))
    action = request.get('action')

    if action == 'request':
        if available_tokens > 0:
            available_tokens -= 1
            response = {"status": "granted", "tokens_left": available_tokens}
            print(f"[+] Granted token to {addr[0]}. Tokens left: {available_tokens}")
        else:
            response = {"status": "denied", "tokens_left": available_tokens}
    
    elif action == 'release':
        if available_tokens < TOTAL_TOKENS:
            available_tokens += 1
        response = {"status": "released", "tokens_left": available_tokens}
        print(f"[-] Token released by {addr[0]}. Tokens left: {available_tokens}")

    sock.sendto(json.dumps(response).encode('utf-8'), addr)
