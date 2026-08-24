#!/usr/bin/env bash
# Clear existing queue limits and bind 100Mbit bottleneck to root interface
sudo tc qdisc del dev eth0 root 2>/dev/null
sudo tc qdisc add dev eth0 root handle 1: tbf rate 100mbit burst 32kbit latency 40ms

# Kill stale instances and start background daemons
sudo fuser -k 5201/tcp 5202/tcp 5203/tcp 2>/dev/null
sleep 1
iperf3 -s -p 5201 -D
iperf3 -s -p 5202 -D
iperf3 -s -p 5203 -D
