#!/usr/bin/env bash

# Load IFB module
sudo modprobe ifb 2>/dev/null || true
sudo ip link add ifb0 type ifb 2>/dev/null || true
sudo ip link set dev ifb0 up 2>/dev/null || true

# Cleanly wipe old traffic control rules
sudo tc qdisc del dev eth0 clsact 2>/dev/null || true
sudo tc qdisc del dev eth0 root 2>/dev/null || true
sudo tc qdisc del dev ifb0 root 2>/dev/null || true

# Direct ingress traffic to IFB
sudo tc qdisc add dev eth0 clsact 2>/dev/null || true
sudo tc filter del dev eth0 ingress 2>/dev/null || true
sudo tc filter add dev eth0 ingress protocol all matchall action mirred egress redirect dev ifb0 2>/dev/null || true

# Configured 1mbit burst / 5mbit limit to support hypervisor GSO super-packets
sudo tc qdisc add dev ifb0 root tbf rate 100mbit burst 1mbit limit 5mbit 2>/dev/null || true

# Reset iperf3 server daemons
sudo fuser -k 5201/tcp 5202/tcp 5203/tcp 2>/dev/null || true
sleep 1
iperf3 -s -p 5201 -D >/dev/null 2>&1
iperf3 -s -p 5202 -D >/dev/null 2>&1
iperf3 -s -p 5203 -D >/dev/null 2>&1

echo "[+] Receiver bottleneck and daemons successfully configured."