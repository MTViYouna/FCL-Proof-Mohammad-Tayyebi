$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = $PWD.Path }

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " ViYouna FCL Proof - Automated Setup" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

$vms = @("gtl-server", "receiver", "sender-1", "sender-2", "sender-3")

Write-Host "`n[*] Checking Multipass & VMs..." -ForegroundColor Yellow
$existingVms = multipass list | Out-String

foreach ($vm in $vms) {
    if ($existingVms -match "\b$vm\b") {
        Write-Host "[*] $vm already exists. Skipping launch." -ForegroundColor DarkGray
    } else {
        Write-Host "[*] Launching $vm..." -ForegroundColor Yellow
        multipass launch 26.04 --name $vm --cpus 1 --mem 1G --disk 5G
    }
}

foreach ($vm in $vms) {
    Write-Host "[*] Updating dependencies on $vm..." -ForegroundColor Yellow
    multipass exec $vm -- sudo apt-get update -y
    multipass exec $vm -- sudo apt-get install -y python3 iperf3 iproute2
}

$gtl_ip = (multipass info gtl-server --format json | ConvertFrom-Json).info.'gtl-server'.ipv4[0]
$rcv_ip = (multipass info receiver --format json | ConvertFrom-Json).info.receiver.ipv4[0]

Write-Host "`n[*] Deploying scripts..." -ForegroundColor Yellow
foreach ($vm in "sender-1", "sender-2", "sender-3") {
    multipass transfer "$ScriptDir/workload.py" "${vm}:/home/ubuntu/workload.py"
}
multipass transfer "$ScriptDir/gtl_server.py" "gtl-server:/home/ubuntu/gtl_server.py"

Write-Host "`n[*] Starting GTL Server..." -ForegroundColor Yellow
multipass exec gtl-server -- pkill -f gtl_server.py 2>$null
multipass exec gtl-server -- nohup python3 /home/ubuntu/gtl_server.py > /home/ubuntu/gtl_server.log 2>&1 &
Start-Sleep -Seconds 2

Write-Host "[+] Setup Complete." -ForegroundColor Green
