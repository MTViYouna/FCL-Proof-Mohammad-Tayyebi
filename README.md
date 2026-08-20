Here is the complete, perfectly formatted Markdown document. I have merged your header, the objective, the architecture, the **methodology**, the test results, and the business impact into one seamless flow.

You can copy everything inside the code block below and paste it directly into your GitHub `README.md` file.

```markdown
# Mohammad-Tayyebi
**#ViYouna #GTL #DCOP #FCL-Proof**

# ViYouna FCL: Eliminating AI Network Incast in Software

### The Objective
To mathematically prove that application-layer pre-transmission coordination (The Fabric Coordination Layer) prevents switch buffer incast and eliminates the "Straggler Tax" in synchronized AI workloads, without requiring proprietary hardware.

### The Architecture
* **3 Sender Nodes:** Simulating a GPU cluster executing simultaneous All-Reduce bursts.
* **1 Receiver Node:** Simulating the fabric switch with constrained queue limits to force a bottleneck.
* **ViYouna GTL:** A software-based Global Token Ledger governing network ingress authority.

---

### Methodology & Testbed Setup
To accurately simulate an AI GPU cluster overwhelming a network fabric, we built a virtualized micro-data center using Canonical Multipass and Hyper-V running Ubuntu Linux nodes.

**1. Creating the Bottleneck (The Fabric Switch)**
To simulate an overwhelmed Ethernet switch port, we used Linux Traffic Control (`tc`) on the Receiver node to intentionally constrain the network queue. We restricted the bandwidth and set a tiny packet limit to ensure that simultaneous bursts would cause immediate buffer overflow.
```bash
sudo tc qdisc add dev eth0 root handle 1: htb default 11
sudo tc class add dev eth0 parent 1: classid 1:11 htb rate 100mbit
sudo tc qdisc add dev eth0 parent 1:11 handle 10: pfifo limit 10

```

**2. The Traffic Generators (The GPU Senders)**
We used `iperf3` to generate heavy, multi-threaded TCP traffic from the 3 Sender nodes, simulating the massive burst of data that occurs during an AI synchronization phase.

**3. Execution**

* **For the Baseline:** We triggered `iperf3` on all 3 Senders at the exact same millisecond, forcing an uncoordinated incast collision.
* **For the ViYouna FCL Test:** We executed the exact same bursts, but wrapped them inside our Pacer script. The script polls the GTL (configured with only 2 available tokens) to ensure the network boundary is respected before data hits the wire.

---

### Phase 1: The Baseline (The "Straggler Tax")

In standard Ethernet networks, AI nodes fire blindly. When all three senders burst simultaneously at our constrained receiver, it immediately causes an incast collision and buffer overflow.

**The Evidence (Uncoordinated Run):**

```text
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-5.00   sec  1017 MBytes  1.71 Gbits/sec   35             sender
[  7]   0.00-5.00   sec   722 MBytes  1.21 Gbits/sec   54             sender
[  9]   0.00-5.00   sec  1.54 GBytes  2.64 Gbits/sec   32             sender
[ 11]   0.00-5.00   sec  1.23 GBytes  2.11 Gbits/sec   27             sender
[SUM]   0.00-5.00   sec  4.47 GBytes  7.67 Gbits/sec  148             sender

```

* **148 Dropped Packets:** The buffer overflowed, forcing massive retransmissions (`Retr`).
* **Stranded Compute:** Stream `[7]` only transferred 722 MBytes, while Stream `[9]` transferred 1.54 GBytes. The synchronization barrier cannot close until Stream 7 finishes, meaning the faster GPUs must sit completely idle waiting for the network.

---

### Phase 2: ViYouna FCL (Coordinated Execution)

We wrap the senders in the ViYouna FCL Pacer. Senders must now request a token from the Global Token Ledger before injecting traffic. The ledger restricts active bursts to perfectly match the physical capacity of the receiver.

**The Evidence (Coordinated Run):**

```text
Starting ViYouna DCOP Pacer...
[-] Token denied. Waiting for fabric capacity...
[-] Token denied. Waiting for fabric capacity...
[-] Token denied. Waiting for fabric capacity...
[+] Token granted! Initiating burst...
Running iperf3 to 192.168.235.111...

[ ID] Interval           Transfer     Bitrate         Retr
[SUM]   0.00-5.00   sec  3.20 GBytes  5.49 Gbits/sec    1             sender

[+] Burst complete. Token released back to ledger.

```

* **Perfect Pacing:** The application logs prove the ledger successfully stalled the 3rd node (`Token denied`), holding its traffic safely in software memory until physical bandwidth became available.
* **Zero Incast:** Packet drops (`Retr`) plummeted from 148 down to exactly 1.

---

### Conclusion & Business Impact

By shifting congestion control from reactive hardware (standard Ethernet) to proactive software orchestration (ViYouna FCL), we can flatten tail-latency variance, eliminate incast packet drops, and recover millions of dollars of stranded GPU compute over standard commodity networks.


How to Run This Proof of Concept (Quick Start Guide)
1. Prerequisites

Install Canonical Multipass (Works on Windows Hyper-V, macOS, and Linux).

2. Spin Up the Virtual Cluster
Open your terminal and run these commands to create the 5 lightweight Ubuntu nodes:

Bash
multipass launch --name gtl-server --cpus 1 --mem 1G --disk 5G
multipass launch --name receiver --cpus 1 --mem 1G --disk 5G
multipass launch --name sender-1 --cpus 1 --mem 1G --disk 5G
multipass launch --name sender-2 --cpus 1 --mem 1G --disk 5G
multipass launch --name sender-3 --cpus 1 --mem 1G --disk 5G
3. Install Dependencies on All Nodes

Bash
foreach ($vm in "gtl-server", "receiver", "sender-1", "sender-2", "sender-3") {
    multipass exec $vm -- sudo apt-get update -y
    multipass exec $vm -- sudo apt-get install -y python3 iperf3 iproute2
}
4. Set Up the Receiver (The Bottleneck)
Log into the receiver to create the network bottleneck and start the background listeners:

Bash
multipass shell receiver
sudo tc qdisc add dev eth0 root handle 1: htb default 11
sudo tc class add dev eth0 parent 1: classid 1:11 htb rate 100mbit
sudo tc qdisc add dev eth0 parent 1:11 handle 10: pfifo limit 10
iperf3 -s -p 5201 -D
iperf3 -s -p 5202 -D
iperf3 -s -p 5203 -D
exit
5. Start the Global Token Ledger
Log into the GTL server, add the gtl_server.py script, and run it:

Bash
multipass shell gtl-server
# (Add gtl_server.py here)
python3 gtl_server.py
(Leave this terminal window open so the server keeps running).

6. Run the Pacer on the Senders
In a new terminal window, add pacer.py to your sender nodes. Make sure to update the GTL_IP, RECEIVER_IP, and RECEIVER_PORT variables inside the script to match your local Multipass IPs. Then, trigger them simultaneously:

Bash
Start-Job -ScriptBlock { multipass exec sender-1 -- python3 pacer.py }
Start-Job -ScriptBlock { multipass exec sender-2 -- python3 pacer.py }
Start-Job -ScriptBlock { multipass exec sender-3 -- python3 pacer.py }
Get-Job | Wait-Job | Receive-Job
