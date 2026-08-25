#!/usr/bin/env bash
# Unify all traffic control (tc) rules for Ingress shaping via IFB

# 1. Load module and create interface
sudo modprobe ifb
sudo ip link add ifb0 type ifb 2>/dev/null || true
sudo ip link set dev ifb0 up

# 2. Clear old rules to prevent conflicts
sudo tc qdisc del dev eth0 clsact 2>/dev/null || true
sudo tc qdisc del dev ifb0 root 2>/dev/null || true

# 3. Redirect eth0 incoming traffic to ifb0
sudo tc qdisc add dev eth0 clsact
sudo tc filter add dev eth0 ingress protocol all matchall action mirred egress redirect dev ifb0

# 4. Apply the strict 100Mbit bottleneck to ifb0
sudo tc qdisc add dev ifb0 root tbf rate 100mbit burst 32kbit latency 50ms

# 5. Force kill any stuck iperf3 daemons and restart them cleanly
sudo fuser -k 5201/tcp 5202/tcp 5203/tcp 2>/dev/null
sleep 1
iperf3 -s -p 5201 -D
iperf3 -s -p 5202 -D
iperf3 -s -p 5203 -D

echo "[+] Receiver bottleneck and daemons successfully configured."
