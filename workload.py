import sys
import time
import json
import socket
import subprocess
import os


if len(sys.argv) != 5:
    print(
        "Usage: python3 workload.py "
        "<receiver_port> <True|False> <gtl_ip> <receiver_ip>"
    )
    sys.exit(1)


PORT = int(sys.argv[1])
FCL_ACTIVE = sys.argv[2] == "True"
GTL_IP = sys.argv[3]
RECEIVER_IP = sys.argv[4]

METRICS_PATH = "/tmp/metrics.json"

# Remove stale telemetry.
if os.path.exists(METRICS_PATH):
    os.remove(METRICS_PATH)

wait_time = 0.0
gtl_granted = False

sock = None

if FCL_ACTIVE:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(1.0)

    t0 = time.time()

    while True:
        try:
            request = json.dumps({
                "action": "request"
            }).encode("utf-8")

            sock.sendto(
                request,
                (GTL_IP, 5000)
            )

            data, _ = sock.recvfrom(1024)
            response = json.loads(data.decode("utf-8"))

            if response.get("status") == "granted":
                gtl_granted = True
                break

        except (socket.timeout, OSError, ValueError):
            pass

        elapsed = time.time() - t0

        print(
            f"[Port {PORT}] "
            f"WAITING FOR GTL TOKEN... "
            f"Elapsed: {elapsed:.1f}s",
            end="\r",
            flush=True
        )

        time.sleep(0.3)

    wait_time = time.time() - t0

    print(
        f"[Port {PORT}] TOKEN GRANTED! "
        f"(Wait: {wait_time:.2f}s)"
    )

t1 = time.time()

cmd = [
    "iperf3",
    "-c",
    RECEIVER_IP,
    "-p",
    str(PORT),
    "-n",
    "100M",
    "-J"
]

res = subprocess.run(
    cmd,
    capture_output=True,
    text=True
)

t2 = time.time()

total_retr = 0
bps = 0.0

try:
    data = json.loads(res.stdout)

    total_retr = int(
        data["end"]["sum_sent"]["retransmits"]
    )

    bps = (
        data["end"]["sum_sent"]["bits_per_second"]
        / 1e6
    )

except (KeyError, TypeError, ValueError, json.JSONDecodeError):
    print("[!] Unable to parse iperf3 JSON output.")

if FCL_ACTIVE and gtl_granted and sock is not None:
    try:
        sock.sendto(
            json.dumps({
                "action": "release"
            }).encode("utf-8"),
            (GTL_IP, 5000)
        )
    except OSError:
        pass

if sock is not None:
    sock.close()

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

print(
    f"[+] Port {PORT} Finished | "
    f"Wait: {wait_time:.2f}s | "
    f"Transfer: {transfer_time:.2f}s | "
    f"Retr: {total_retr}"
)
