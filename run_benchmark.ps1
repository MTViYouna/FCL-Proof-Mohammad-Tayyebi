Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " FABRIC COORDINATION LAYER (FCL) BENCHMARK SUITE   " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ----------------------------------------------------
# 1. Discover dynamic Multipass IP addresses
# ----------------------------------------------------

$gtl_ip = (
    multipass info gtl-server --format json |
    ConvertFrom-Json
).info.'gtl-server'.ipv4[0]

$rcv_ip = (
    multipass info receiver --format json |
    ConvertFrom-Json
).info.receiver.ipv4[0]

$vms = @(
    'sender-1',
    'sender-2',
    'sender-3'
)

Write-Host "`n[*] GTL Server IP : $gtl_ip" -ForegroundColor Green
Write-Host "[*] Receiver IP   : $rcv_ip" -ForegroundColor Green

# ----------------------------------------------------
# 2. Deploy the latest workload.py to all senders
# ----------------------------------------------------

Write-Host "`n[*] Deploying workload.py..." -ForegroundColor Yellow

foreach ($vm in $vms) {

    Write-Host "    -> $vm"

    multipass transfer `
        workload.py `
        "${vm}:/home/ubuntu/workload.py"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to deploy workload.py to $vm"
        exit 1
    }
}

Write-Host "[+] workload.py deployed to all sender VMs." -ForegroundColor Green

# ----------------------------------------------------
# 3. Verify workload.py exists on every sender
# ----------------------------------------------------

foreach ($vm in $vms) {

    $check = multipass exec $vm -- `
        test -f /home/ubuntu/workload.py

    if ($LASTEXITCODE -ne 0) {
        Write-Error "workload.py is missing on $vm"
        exit 1
    }
}

Write-Host "[+] workload.py verified on all senders." -ForegroundColor Green

# ----------------------------------------------------
# 4. Results collection
# ----------------------------------------------------

[System.Collections.ArrayList]$all_results = @()

# ----------------------------------------------------
# 5. Benchmark function
# ----------------------------------------------------

function Invoke-BenchmarkRun {
    param(
        [string]$Mode,
        [int]$TestOrder
    )

    Write-Host "`n-----------------------------------------------" -ForegroundColor Cyan

    if ($Mode -eq "False") {
        Write-Host " TEST $TestOrder : BASELINE (WITHOUT GTL)" -ForegroundColor Yellow
    }
    else {
        Write-Host " TEST $TestOrder : FCL / GTL COORDINATED" -ForegroundColor Green
    }

    Write-Host "-----------------------------------------------" -ForegroundColor Cyan

    # ------------------------------------------------
    # Clear stale telemetry
    # ------------------------------------------------

    Write-Host "[*] Clearing stale metrics..." -ForegroundColor Yellow

    foreach ($vm in $vms) {
        multipass exec $vm -- rm -f /tmp/metrics.json
    }

    # ------------------------------------------------
    # Launch all 3 senders concurrently
    #
    # workload.py argument order:
    #
    #   <PORT> <FCL> <GTL_IP> <RECEIVER_IP>
    # ------------------------------------------------

    Write-Host "[*] Launching sender workloads..." -ForegroundColor Yellow

    $p1 = Start-Process `
        multipass `
        -ArgumentList "exec sender-1 -- python3 /home/ubuntu/workload.py 5201 $Mode $gtl_ip $rcv_ip" `
        -NoNewWindow `
        -PassThru

    $p2 = Start-Process `
        multipass `
        -ArgumentList "exec sender-2 -- python3 /home/ubuntu/workload.py 5202 $Mode $gtl_ip $rcv_ip" `
        -NoNewWindow `
        -PassThru

    $p3 = Start-Process `
        multipass `
        -ArgumentList "exec sender-3 -- python3 /home/ubuntu/workload.py 5203 $Mode $gtl_ip $rcv_ip" `
        -NoNewWindow `
        -PassThru

    $processes = @(
        $p1,
        $p2,
        $p3
    )

    # ------------------------------------------------
    # Wait for all three workloads
    # ------------------------------------------------

    Write-Host "[*] Waiting for all sender workloads..." -ForegroundColor Yellow

    $processes | Wait-Process

    # ------------------------------------------------
    # Check process exit codes
    # ------------------------------------------------

    $failed = $false

    foreach ($p in $processes) {

        if ($p.ExitCode -ne 0) {

            Write-Host `
                "[!] Process PID $($p.Id) failed with ExitCode=$($p.ExitCode)" `
                -ForegroundColor Red

            $failed = $true
        }
    }

    if ($failed) {
        Write-Error "Benchmark execution failed."
        return
    }

    Write-Host "[+] All sender workloads completed successfully." -ForegroundColor Green

    # ------------------------------------------------
    # Collect telemetry
    # ------------------------------------------------

    foreach ($item in @(
        @('sender-1', 5201),
        @('sender-2', 5202),
        @('sender-3', 5203)
    )) {

        $vm = $item[0]
        $expectedPort = $item[1]

        Write-Host "[*] Collecting metrics from $vm..." -ForegroundColor Yellow

        $jsonRaw = multipass exec `
            $vm `
            -- cat /tmp/metrics.json `
            2>$null

        if (-not $jsonRaw) {

            Write-Warning `
                "No metrics.json returned from $vm"

            continue
        }

        try {

            $j = $jsonRaw | ConvertFrom-Json

        }
        catch {

            Write-Warning `
                "Invalid JSON telemetry returned from $vm"

            continue
        }

        # --------------------------------------------
        # Validate reported port
        # --------------------------------------------

        if ([int]$j.Port -ne $expectedPort) {

            Write-Warning `
                "Expected port $expectedPort from $vm but telemetry reported $($j.Port)"
        }

        # --------------------------------------------
        # Determine measured state
        # --------------------------------------------

        if ($j.GTL_Enabled -and $j.TokenWait_s -gt 0) {

            $netState = "Application Paced"

        }
        elseif (-not $j.GTL_Enabled -and $j.Retransmissions -gt 0) {

            $netState = "Baseline TCP Retransmissions"

        }
        elseif ($j.Retransmissions -gt 0) {

            $netState = "TCP Retransmissions Observed"

        }
        else {

            $netState = "No Retransmissions Reported"
        }

        # --------------------------------------------
        # Build result object
        # --------------------------------------------

        $obj = [PSCustomObject]@{

            "TestOrder"       = $TestOrder

            "Node / Port"     = "Node $($j.Port)"

            "GTL Mode"        = if ($j.GTL_Enabled) {
                "With GTL"
            }
            else {
                "Without GTL"
            }

            "GTL Granted"     = $j.GTL_Granted

            "Wait Time"       = "$($j.TokenWait_s)s"

            "Transfer Time"   = "$($j.TransferTime_s)s"

            "Throughput"      = "$($j.Throughput_Mbps) Mbps"

            "TCP Retransmits" = $j.Retransmissions

            "Measured State"  = $netState
        }

        $all_results.Add($obj) | Out-Null
    }
}

# ----------------------------------------------------
# 6. Test 1 - Baseline
# ----------------------------------------------------

Write-Host "`n[*] Executing Test 1: Baseline (Without GTL)..." -ForegroundColor Yellow

Invoke-BenchmarkRun `
    -Mode "False" `
    -TestOrder 1

# ----------------------------------------------------
# 7. Pause between experiments
# ----------------------------------------------------

Write-Host "`n[*] Waiting 2 seconds before GTL test..." -ForegroundColor Cyan

Start-Sleep -Seconds 2

# ----------------------------------------------------
# 8. Test 2 - FCL / GTL
# ----------------------------------------------------

Write-Host "`n[*] Executing Test 2: Coordinated (With GTL)..." -ForegroundColor Green

Invoke-BenchmarkRun `
    -Mode "True" `
    -TestOrder 2

# ----------------------------------------------------
# 9. Final comparison
# ----------------------------------------------------

Write-Host "`n=================================================================================" -ForegroundColor Green
Write-Host "                        VERIFIED BENCHMARK TELEMETRY                             " -ForegroundColor Green
Write-Host "=================================================================================" -ForegroundColor Green

$all_results |
    Sort-Object "Node / Port", "TestOrder" |
    Select-Object `
        "Node / Port",
        "GTL Mode",
        "GTL Granted",
        "Wait Time",
        "Transfer Time",
        "Throughput",
        "TCP Retransmits",
        "Measured State" |
    Format-Table -AutoSize
