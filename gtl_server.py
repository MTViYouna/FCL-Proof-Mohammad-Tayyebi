import socket, json, sys

HOST = '0.0.0.0'
PORT = 5000
TOTAL_TOKENS = int(sys.argv[1]) if len(sys.argv) > 1 else 1

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((HOST, PORT))

available_tokens = TOTAL_TOKENS
active_grants = set()  # Set of client_ids currently holding tokens

print(f"[*] ViYouna GTL Server running on {HOST}:{PORT} (Total Tokens: {TOTAL_TOKENS})")

while True:
    try:
        data, addr = sock.recvfrom(1024)
        request = json.loads(data.decode('utf-8'))
        action = request.get('action')
        client_id = request.get('client_id', str(addr[0]))

        if action == 'request':
            # Idempotent Grant: Re-issue token to same client without decrementing
            if client_id in active_grants:
                response = {"status": "granted", "tokens_left": available_tokens}
            elif available_tokens > 0:
                available_tokens -= 1
                active_grants.add(client_id)
                response = {"status": "granted", "tokens_left": available_tokens}
            else:
                response = {"status": "denied", "tokens_left": available_tokens}

        elif action == 'release':
            # Verified Release: Only return token if client holds active grant
            if client_id in active_grants:
                active_grants.remove(client_id)
                available_tokens = min(TOTAL_TOKENS, available_tokens + 1)
                response = {"status": "released", "tokens_left": available_tokens}
            else:
                response = {"status": "ignored", "tokens_left": available_tokens}

        elif action == 'reset':
            active_grants.clear()
            available_tokens = TOTAL_TOKENS
            response = {"status": "reset", "tokens_left": available_tokens}

        sock.sendto(json.dumps(response).encode('utf-8'), addr)
    except Exception as e:
        print(f"[!] Server Error: {e}")