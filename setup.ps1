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
