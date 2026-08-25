import sys
import time
import json
import socket
import subprocess
import os

if len(sys.argv) != 5:
    print("Usage: python3 workload.py <port> <True|False> <gtl_ip> <receiver_ip>")
    sys.exit(1)

PORT = int(sys.argv[1])
FCL_ACTIVE = sys.argv[2] == "True"
GTL_IP = sys.argv[3]
RECEIVER_IP = sys.argv[4]
METRICS_PATH = "/tmp/metrics.json"

if os.path.exists(METRICS_PATH):
    os.remove(METRICS_PATH)

wait_time = 0.0
gtl_granted = False
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(1.0)

try:
    if FCL_ACTIVE:
        t0 = time.time()
        while True:
            try:
                sock.sendto(json.dumps({"action": "request"}).encode("utf-8"), (GTL_IP, 5000))
                data, _ = sock.recvfrom(1024)
                if json.loads(data.decode("utf-8")).get("status") == "granted":
                    gtl_granted = True
                    break
            except (socket.timeout, OSError):
                pass
            
            elapsed = time.time() - t0
            print(f"[Port {PORT}] WAITING FOR GTL TOKEN... Elapsed: {elapsed:.1f}s", end="\r", flush=True)
            time.sleep(0.3)

        wait_time = time.time() - t0
        print(f"\n[Port {PORT}] TOKEN GRANTED! (Wait: {wait_time:.2f}s)")

    t1 = time.time()
    cmd = ["iperf3", "-c", RECEIVER_IP, "-p", str(PORT), "-n", "100M", "-J"]
    
    res = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    t2 = time.time()

    total_retr = 0
    bps = 0.0
    try:
        data = json.loads(res.stdout)
        total_retr = int(data["end"]["sum_sent"]["retransmits"])
        bps = data["end"]["sum_sent"]["bits_per_second"] / 1e6
    except Exception:
        print("[!] Unable to parse iperf3 output or transfer failed.")

    transfer_time = t2 - t1

    metrics = {
        "Port": PORT,
        "GTL_Enabled": FCL_ACTIVE,
        "GTL_Granted": gtl_granted,
        "TokenWait_s": round(wait_time, 2),
        "TransferTime_s": round(transfer_time, 2),
        "Throughput_Mbps": round(bps, 2),
        "Retransmissions": total_retr
    }

    with open(METRICS_PATH, "w") as f:
        json.dump(metrics, f)

    print(f"[+] Port {PORT} Finished | Wait: {wait_time:.2f}s | Transfer: {transfer_time:.2f}s | Retr: {total_retr}")

finally:
    if FCL_ACTIVE and gtl_granted:
        try:
            sock.sendto(json.dumps({"action": "release"}).encode("utf-8"), (GTL_IP, 5000))
        except:
            pass
    sock.close()
