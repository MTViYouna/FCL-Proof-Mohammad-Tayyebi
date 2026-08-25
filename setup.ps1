$ErrorActionPreference = "Stop"

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " ViYouna FCL Proof - Automated Setup" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

$vms = @(
    "gtl-server",
    "receiver",
    "sender-1",
    "sender-2",
    "sender-3"
)

Write-Host "`n[*] Checking Multipass..." -ForegroundColor Yellow

multipass version

Write-Host "`n[*] Launching virtual cluster..." -ForegroundColor Yellow

multipass launch 26.04 --name gtl-server --cpus 1 --mem 1G --disk 5G
multipass launch 26.04 --name receiver --cpus 1 --mem 1G --disk 5G
multipass launch 26.04 --name sender-1 --cpus 1 --mem 1G --disk 5G
multipass launch 26.04 --name sender-2 --cpus 1 --mem 1G --disk 5G
multipass launch 26.04 --name sender-3 --cpus 1 --mem 1G --disk 5G

foreach ($vm in $vms) {
    Write-Host "[*] Installing dependencies on $vm..." -ForegroundColor Yellow

    multipass exec $vm -- sudo apt-get update -y
    multipass exec $vm -- sudo apt-get install -y python3 iperf3 iproute2
}

$gtl_ip = (
    multipass info gtl-server --format json |
    ConvertFrom-Json
).info.'gtl-server'.ipv4[0]

$rcv_ip = (
    multipass info receiver --format json |
    ConvertFrom-Json
).info.receiver.ipv4[0]

Write-Host "`n[*] GTL Server IP : $gtl_ip" -ForegroundColor Green
Write-Host "[*] Receiver IP   : $rcv_ip" -ForegroundColor Green


foreach ($vm in "sender-1", "sender-2", "sender-3") {
    Write-Host "[*] Copying workload.py to $vm..." -ForegroundColor Yellow

    multipass transfer `
        workload.py `
        "${vm}:/home/ubuntu/workload.py"
}

multipass transfer `
    gtl_server.py `
    "gtl-server:/home/ubuntu/gtl_server.py"


Write-Host "`n[*] Configuring receiver bottleneck..." -ForegroundColor Yellow

multipass exec receiver -- sudo modprobe ifb
multipass exec receiver -- sudo ip link add ifb0 type ifb
multipass exec receiver -- sudo ip link set dev ifb0 up
multipass exec receiver -- sudo tc qdisc add dev eth0 clsact

multipass exec receiver -- sudo tc filter add dev eth0 ingress `
    protocol all `
    matchall `
    action mirred egress redirect dev ifb0

multipass exec receiver -- sudo tc qdisc add dev ifb0 root tbf `
    rate 100mbit `
    burst 32kbit `
    latency 50ms


multipass exec receiver -- iperf3 -s -p 5201 -D
multipass exec receiver -- iperf3 -s -p 5202 -D
multipass exec receiver -- iperf3 -s -p 5203 -D

multipass exec gtl-server -- `
    nohup python3 /home/ubuntu/gtl_server.py `
    > /home/ubuntu/gtl_server.log 2>&1 &


multipass exec gtl-server -- pgrep -af gtl_server.py
