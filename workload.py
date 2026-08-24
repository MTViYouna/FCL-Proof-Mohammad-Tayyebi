$gtl_ip = (multipass info gtl-server --format json | ConvertFrom-Json).info.'gtl-server'.ipv4[0]
$rcv_ip = (multipass info receiver --format json | ConvertFrom-Json).info.'receiver'.ipv4[0]

$script = @"
import sys, time, json, socket, subprocess, os

PORT = int(sys.argv[1])
FCL_ACTIVE = sys.argv[2] == 'True'
RECEIVER_IP = '$rcv_ip'
GTL_IP = '$gtl_ip'
METRICS_PATH = '/tmp/metrics.json'

# Clean stale metrics file immediately on startup
if os.path.exists(METRICS_PATH):
    os.remove(METRICS_PATH)

wait_time = 0.0
gtl_granted = False

if FCL_ACTIVE:
    t0 = time.time()
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(1.0)
    
    while True:
        try:
            s.sendto(json.dumps({'action':'request'}).encode(), (GTL_IP, 5000))
            data, _ = s.recvfrom(1024)
            if json.loads(data.decode()).get('status') == 'granted':
                gtl_granted = True
                break
        except (socket.timeout, Exception):
            pass
        
        elapsed = time.time() - t0
        sys.stdout.write(f"\r[Port {PORT}] WAITING FOR GTL TOKEN... Elapsed: {elapsed:.1f}s")
        sys.stdout.flush()
        time.sleep(0.3)
        
    wait_time = time.time() - t0
    sys.stdout.write(f"\r[Port {PORT}] TOKEN GRANTED! (Wait: {wait_time:.2f}s)\n")
    sys.stdout.flush()

t1 = time.time()

# Run iperf3 with JSON formatting (-J) for programmatic accuracy
cmd = ['iperf3', '-c', RECEIVER_IP, '-p', str(PORT), '-n', '100M', '-J']
res = subprocess.run(cmd, capture_output=True, text=True)
t2 = time.time()

total_retr = 0
bps = 0.0

try:
    data = json.loads(res.stdout)
    total_retr = data['end']['sum_sent']['retransmits']
    bps = data['end']['sum_sent']['bits_per_second'] / 1e6
except Exception:
    pass

if FCL_ACTIVE and gtl_granted:
    try:
        s.sendto(json.dumps({'action':'release'}).encode(), (GTL_IP, 5000))
    except:
        pass

transfer_time = t2 - t1

# Explicit measured telemetry output
metrics = {
    "Port": PORT,
    "GTL_Enabled": FCL_ACTIVE,
    "GTL_Granted": gtl_granted,
    "TokenWait_s": round(wait_time, 2),
    "TransferTime_s": round(transfer_time, 2),
    "Throughput_Mbps": round(bps, 2),
    "Retransmissions": total_retr
}

with open(METRICS_PATH, 'w') as f:
    json.dump(metrics, f)

print(f"[+] Port {PORT} Finished | Wait: {wait_time:.2f}s | Transfer: {transfer_time:.2f}s | Retr: {total_retr}")
"@

Set-Content -Path "workload_clean.py" -Value $script
foreach ($vm in "sender-1", "sender-2", "sender-3") { multipass transfer workload_clean.py ${vm}:workload.py }
