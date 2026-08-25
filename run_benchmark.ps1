param(
    [int]$Tokens = 1
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = $PWD.Path }

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " FABRIC COORDINATION LAYER (FCL) BENCHMARK SUITE   " -ForegroundColor Cyan
Write-Host " Target GTL Token Limit: $Tokens                   " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$gtl_ip = (multipass info gtl-server --format json | ConvertFrom-Json).info.'gtl-server'.ipv4[0]
$rcv_ip = (multipass info receiver --format json | ConvertFrom-Json).info.receiver.ipv4[0]
$vms = @('sender-1', 'sender-2', 'sender-3')

[System.Collections.ArrayList]$all_results = @()

function Invoke-BenchmarkRun {
    param([string]$Mode, [int]$TestOrder)

    Write-Host "`n-----------------------------------------------" -ForegroundColor Cyan
    Write-Host " PREPARING TEST $TestOrder (FCL: $Mode, Tokens: $Tokens)" -ForegroundColor Yellow
    Write-Host "-----------------------------------------------" -ForegroundColor Cyan

    multipass exec receiver -- bash /home/ubuntu/setup_receiver.sh | Out-Null

    Write-Host "[*] Configuring GTL Server with $Tokens token(s)..."
    multipass exec gtl-server -- sudo systemctl stop gtl-server 2>$null
    multipass exec gtl-server -- pkill -9 -f gtl_server.py 2>$null
    multipass exec gtl-server -- sudo systemd-run --unit=gtl-server python3 -u /home/ubuntu/gtl_server.py $Tokens | Out-Null
    Start-Sleep -Seconds 1

    foreach ($vm in $vms) { multipass exec $vm -- rm -f /tmp/metrics.json }

    $p1 = Start-Process multipass -ArgumentList "exec sender-1 -- python3 /home/ubuntu/workload.py 5201 $Mode $gtl_ip $rcv_ip" -NoNewWindow -PassThru
    $p2 = Start-Process multipass -ArgumentList "exec sender-2 -- python3 /home/ubuntu/workload.py 5202 $Mode $gtl_ip $rcv_ip" -NoNewWindow -PassThru
    $p3 = Start-Process multipass -ArgumentList "exec sender-3 -- python3 /home/ubuntu/workload.py 5203 $Mode $gtl_ip $rcv_ip" -NoNewWindow -PassThru

    $p1, $p2, $p3 | Wait-Process

    foreach ($item in @(@('sender-1', 5201), @('sender-2', 5202), @('sender-3', 5203))) {
        $vm = $item[0]
        $jsonRaw = multipass exec $vm -- cat /tmp/metrics.json 2>$null
        
        if (-not $jsonRaw) { throw "CRITICAL FAILURE: No metrics.json returned from $vm." }
        try { $j = $jsonRaw | ConvertFrom-Json } 
        catch { throw "CRITICAL FAILURE: Invalid JSON telemetry returned from $vm." }

        $netState = if ($j.GTL_Enabled -and $j.TokenWait_s -gt 0) { "Application Paced" } 
                    elseif ($j.Retransmissions -gt 0) { "TCP Retransmissions Observed" } 
                    else { "No Retransmissions Reported" }

        $obj = [PSCustomObject]@{
            "TestOrder"       = $TestOrder
            "Node / Port"     = "Node $($j.Port)"
            "GTL Mode"        = if ($j.GTL_Enabled) { "With GTL ($Tokens Token)" } else { "Without GTL" }
            "Wait Time"       = "$($j.TokenWait_s)s"
            "Transfer Time"   = "$($j.TransferTime_s)s"
            "Throughput"      = "$($j.Throughput_Mbps) Mbps"
            "TCP Retransmits" = $j.Retransmissions
            "Measured State"  = $netState
        }
        $all_results.Add($obj) | Out-Null
    }
}

Invoke-BenchmarkRun -Mode "False" -TestOrder 1
Start-Sleep -Seconds 2
Invoke-BenchmarkRun -Mode "True" -TestOrder 2

Write-Host "`n=================================================================================" -ForegroundColor Green
$all_results | Sort-Object "Node / Port", "TestOrder" | Select-Object "Node / Port", "GTL Mode", "Wait Time", "Transfer Time", "Throughput", "TCP Retransmits", "Measured State" | Format-Table -AutoSize