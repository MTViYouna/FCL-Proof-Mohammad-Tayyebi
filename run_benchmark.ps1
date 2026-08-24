Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " FABRIC COORDINATION LAYER (FCL) BENCHMARK SUITE   " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# Fetch dynamic IPs
$gtl_ip = (multipass info gtl-server --format json | ConvertFrom-Json).info.'gtl-server'.ipv4[0]
$rcv_ip = (multipass info receiver --format json | ConvertFrom-Json).info.'receiver'.ipv4[0]
$vms = @('sender-1', 'sender-2', 'sender-3')

# Deploy latest workload script
foreach ($vm in $vms) {
    multipass transfer workload.py ${vm}:workload.py
}

[System.Collections.ArrayList]$all_results = @()

function Invoke-BenchmarkRun {
    param([string]$Mode, [int]$TestOrder)
    
    # Clear stale metrics
    foreach ($vm in $vms) {
        multipass exec $vm -- rm -f /tmp/metrics.json
    }

    $p1 = Start-Process multipass -ArgumentList "exec sender-1 -- python3 workload.py 5201 $Mode $rcv_ip $gtl_ip" -NoNewWindow -PassThru
    $p2 = Start-Process multipass -ArgumentList "exec sender-2 -- python3 workload.py 5202 $Mode $rcv_ip $gtl_ip" -NoNewWindow -PassThru
    $p3 = Start-Process multipass -ArgumentList "exec sender-3 -- python3 workload.py 5203 $Mode $rcv_ip $gtl_ip" -NoNewWindow -PassThru

    $p1, $p2, $p3 | Wait-Process

    if ($p1.ExitCode -ne 0 -or $p2.ExitCode -ne 0 -or $p3.ExitCode -ne 0) {
        Write-Error "Benchmark execution failed! Exit Codes: P1=$($p1.ExitCode), P2=$($p2.ExitCode), P3=$($p3.ExitCode)"
        return
    }

    foreach ($item in @(@('sender-1', 5201), @('sender-2', 5202), @('sender-3', 5203))) {
        $vm = $item[0]
        $jsonRaw = multipass exec $vm -- cat /tmp/metrics.json 2>$null
        
        if ($jsonRaw) {
            $j = $jsonRaw | ConvertFrom-Json
            $netState = if ($j.Retransmissions -gt 1000) { "High Congestion ($($j.Retransmissions) Retr)" } elseif ($j.TokenWait_s -gt 0) { "Application Paced ($($j.TokenWait_s)s Hold)" } else { "Uncongested Link" }

            $obj = [PSCustomObject]@{
                "TestOrder"       = $TestOrder
                "Node / Port"     = "Node $($j.Port)"
                "GTL Mode"        = if ($j.GTL_Enabled) { "With GTL" } else { "Without GTL" }
                "Wait Time"       = "$($j.TokenWait_s)s"
                "Transfer Time"   = "$($j.TransferTime_s)s"
                "Throughput"      = "$($j.Throughput_Mbps) Mbps"
                "TCP Retransmits" = $j.Retransmissions
                "Measured State"  = $netState
            }
            $all_results.Add($obj) | Out-Null
        }
    }
}

Write-Host "`n[*] Executing Test 1: Baseline (Without GTL)..." -ForegroundColor Yellow
Invoke-BenchmarkRun -Mode "False" -TestOrder 1

Start-Sleep -Seconds 2

Write-Host "`n[*] Executing Test 2: Coordinated (With GTL)..." -ForegroundColor Green
Invoke-BenchmarkRun -Mode "True" -TestOrder 2

Write-Host "`n=================================================================================" -ForegroundColor Green
Write-Host "                        VERIFIED BENCHMARK TELEMETRY                             " -ForegroundColor Green
Write-Host "=================================================================================" -ForegroundColor Green
$all_results | Sort-Object "Node / Port", "TestOrder" | Select-Object -Property "Node / Port", "GTL Mode", "Wait Time", "Transfer Time", "Throughput", "TCP Retransmits", "Measured State" | Format-Table -AutoSize
