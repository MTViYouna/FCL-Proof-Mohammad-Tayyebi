import socket
import json
import subprocess
import time
import sys

# Configuration
GTL_IP = '192.168.231.87'       # UPDATE: Your GTL Server IP Address
GTL_PORT = 5000
RECEIVER_IP = '192.168.235.111' # UPDATE: Your Receiver (Switch) IP Address
RECEIVER_PORT = '5201'          # UPDATE: Change to 5202, 5203, etc., for additional sender nodes

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(2.0)

def request_token():
    message = json.dumps({"action": "request"}).encode('utf-8')
    while True:
        try:
            sock.sendto(message, (GTL_IP, GTL_PORT))
            data, _ = sock.recvfrom(1024)
            response = json.loads(data.decode('utf-8'))
            
            if response.get("status") == "granted":
                print("[+] Token granted! Initiating burst...")
                return True
            else:
                print("[-] Token denied. Waiting for fabric capacity...")
                time.sleep(0.5) # Wait half a second before trying again
        except socket.timeout:
            print("[!] Timeout reaching GTL server. Retrying...")

def release_token():
    message = json.dumps({"action": "release"}).encode('utf-8')
    sock.sendto(message, (GTL_IP, GTL_PORT))
    print("[+] Burst complete. Token released back to ledger.")

if __name__ == "__main__":
    print("Starting ViYouna DCOP Pacer...")
    
    # Step 1: Pre-transmission Coordination
    request_token()
    
    # Step 2: Inject Traffic (Now that we have authority)
    print(f"Running iperf3 to {RECEIVER_IP} on port {RECEIVER_PORT}...")
    
    # Running a 5-second burst
    subprocess.run(["iperf3", "-c", RECEIVER_IP, "-p", RECEIVER_PORT, "-t", "5", "-P", "4"])
    
    # Step 3: Reconcile Authority
    release_token()
