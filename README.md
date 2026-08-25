<p><strong>#ViYouna #GTL #DCOP #FCL-Proof</strong></p>
<h4>by Mohammad Tayyebi</h4>
<h1>Experimental Validation: Software-Based Ingress Coordination Reduces TCP Retransmissions</h1>

<h3>The Objective</h3>
<p>To empirically demonstrate that application-layer pre-transmission admission control (the Fabric Coordination Layer) can mitigate network incast contention, reduce TCP retransmissions, and increase active flow throughput in synchronized multi-node workloads without requiring custom network hardware.</p>

<h3>The Architecture</h3>
<ul>
<li><strong>3 Sender Nodes:</strong> Simulating compute nodes executing concurrent 30MB bursts.</li>
<li><strong>1 Receiver Node:</strong> Providing a controlled constrained network path (100 Mbit/s bottleneck).</li>
<li><strong>ViYouna GTL:</strong> A software-based Global Token Ledger governing socket admission authority over UDP.</li>
</ul>

<h2>Architecture Topology</h2>
<ul>
<li><strong>GTL Server (<code>gtl-server</code>):</strong> Central token ledger managing application admission leases.</li>
<li><strong>Sender VMs (<code>sender-1</code>, <code>sender-2</code>, <code>sender-3</code>):</strong> Compute nodes executing parallel 30MB TCP workloads.</li>
<li><strong>Receiver VM (<code>receiver</code>):</strong> Ingress target configured with a controlled 100 Mbit/s Linux Traffic Control (<code>tbf</code>) queue constraint.</li>
</ul>

<hr>

<h3>Methodology & Testbed Setup</h3>
<p>To evaluate admission control mechanics, we constructed a virtualized testbed using Canonical Multipass with Hyper-V.</p>

<p><strong>1. Level 1 & 2 Validation: Queue Constraint & Retransmissions</strong></p>
<p>We apply Linux Traffic Control (<code>tc</code>) on the receiver to enforce a <strong>100 Mbit/s</strong> bottleneck with a <code>1mbit burst / 5mbit limit</code> queue buffer on an Intermediate Functional Block (<code>ifb0</code>) ingress interface.</p>
<p>Concurrent 30MB TCP transfers are generated across 3 Senders using <code>iperf3</code> to record socket throughput and kernel-reported TCP retransmissions under uncoordinated contention.</p>

<p><strong>2. Level 3 Validation: Application-Layer Pacing</strong></p>
<p>The ViYouna workload orchestration script polls the GTL (configured with a concurrency limit of 1 token) before calling the socket transfer. When no token is available, the process pauses in host application memory rather than launching a concurrent socket stream.</p>
<p>This evaluates whether controlling network admission concurrency reduces transport-layer contention.</p>

<hr>

<h1>How to Run This Proof of Concept (Quick Start Guide)</h1>

<h2>1. Prerequisites</h2>
<p>Install Canonical Multipass on Windows (Hyper-V), macOS, or Linux.</p>

<h2>2. Deploy Cluster Infrastructure</h2>
<pre><code>.\setup.ps1</code></pre>
<p><em>This script provisions all 5 Ubuntu VMs, installs system dependencies (<code>python3</code>, <code>iperf3</code>, <code>iproute2</code>), and deploys the workload scripts to their respective nodes.</em></p>

<h2>3. Execute Dual Benchmark (1-Token Policy)</h2>
<pre><code>.\run_benchmark.ps1 1</code></pre>
<p><em>The orchestrator configures the receiver queue (via <code>setup_receiver.sh</code>), initializes the GTL server with 1 token, executes the Baseline and FCL runs sequentially, and parses verified telemetry from <code>iperf3</code> JSON telemetry.</em></p>

<hr>

<h1>Empirical Telemetry Results</h1>
<p>Telemetry recorded from a single dual-run execution (30MB payload per node, 100 Mbit/s path limit):</p>

<table border="1" cellpadding="8" cellspacing="0">
  <thead>
    <tr>
      <th>Node / Port</th>
      <th>GTL Mode</th>
      <th>App Wait Time</th>
      <th>Active Transfer Time</th>
      <th>Flow Finish Time</th>
      <th>Throughput</th>
      <th>TCP Retransmissions</th>
      <th>Measured Network State</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Node 5201</strong></td>
      <td>Without GTL</td>
      <td>0.00s</td>
      <td>6.06s</td>
      <td>6.06s</td>
      <td>43.15 Mbps</td>
      <td>68</td>
      <td>TCP Retransmissions Observed</td>
    </tr>
    <tr>
      <td><strong>Node 5201</strong></td>
      <td><strong>With GTL (1 Token)</strong></td>
      <td><strong>0.00s</strong></td>
      <td><strong>3.01s</strong></td>
      <td><strong>3.01s</strong></td>
      <td><strong>90.15 Mbps</strong></td>
      <td><strong>0</strong></td>
      <td><strong>No Retransmissions Reported</strong></td>
    </tr>
    <tr>
      <td><strong>Node 5202</strong></td>
      <td>Without GTL</td>
      <td>0.00s</td>
      <td>5.11s</td>
      <td>5.11s</td>
      <td>58.90 Mbps</td>
      <td>334</td>
      <td>TCP Retransmissions Observed</td>
    </tr>
    <tr>
      <td><strong>Node 5202</strong></td>
      <td><strong>With GTL (1 Token)</strong></td>
      <td><strong>6.04s</strong></td>
      <td><strong>3.01s</strong></td>
      <td><strong>9.05s</strong></td>
      <td><strong>90.14 Mbps</strong></td>
      <td><strong>0</strong></td>
      <td><strong>Application Paced</strong></td>
    </tr>
    <tr>
      <td><strong>Node 5203</strong></td>
      <td>Without GTL</td>
      <td>0.00s</td>
      <td>8.30s</td>
      <td>8.30s</td>
      <td>42.86 Mbps</td>
      <td>6</td>
      <td>TCP Retransmissions Observed</td>
    </tr>
    <tr>
      <td><strong>Node 5203</strong></td>
      <td><strong>With GTL (1 Token)</strong></td>
      <td><strong>2.42s</strong></td>
      <td><strong>3.01s</strong></td>
      <td><strong>5.43s</strong></td>
      <td><strong>90.13 Mbps</strong></td>
      <td><strong>0</strong></td>
      <td><strong>Application Paced</strong></td>
    </tr>
  </tbody>
</table>

<hr>

<h1>Key Experimental Insights</h1>

<h3>1. <strong>+86.6% Increase in Active Throughput (1.87× Speedup)</strong></h3>
<p>Baseline average active throughput:<br>
<code>(43.15 + 58.90 + 42.86) / 3 = 48.30 Mbps</code></p>
<p>Coordinated average active throughput:<br>
<code>90.14 Mbps</code></p>
<p>Calculated gain:<br>
<code>(90.14 / 48.30) = 1.866× (+86.6%)</code></p>
<p><strong>Result: Serializing ingress admission increased active flow rate from 48.30 Mbps to 90.14 Mbps by preventing concurrent socket contention.</strong></p>

<hr>

<h3>2. <strong>0 TCP Retransmissions in Coordinated Run</strong></h3>
<p>Baseline total TCP retransmissions: <strong>408 retransmissions</strong><br>
Coordinated total TCP retransmissions: <strong>0 retransmissions</strong></p>

<blockquote>
  <p><strong>Note:</strong> Telemetry reflects kernel-reported TCP retransmissions from <code>iperf3</code> JSON telemetry during this single test run. Direct hardware qdisc drop counters (<code>tc -s qdisc</code>) represent a primary measurement target for Level 4 validation.</p>
</blockquote>

<hr>

<h3>3. <strong>Collective Barrier Completion Time Trade-off (+9.0% Wall-Clock Latency)</strong></h3>
<p>Baseline Collective Barrier Completion Time (Uncoordinated):<br>
<code>max(6.06s, 5.11s, 8.30s) = 8.30 seconds</code></p>
<p>Coordinated Collective Barrier Completion Time (1-Token Policy):<br>
<code>max(3.01s, 9.05s, 5.43s) = 9.05 seconds</code></p>
<p>Calculated Barrier Latency Impact:<br>
<code>(9.05 / 8.30 - 1) * 100 = +9.0% overall wall-clock time</code></p>

<p><strong>Analytical Finding:</strong> Strict single-token admission control doubles active flow throughput and eliminates retransmissions, but introduces an application queuing delay that extends total wall-clock barrier execution from 8.30s to 9.05s (+9.0%). This demonstrates the fundamental architectural trade-off between individual flow serialization and aggregate collective synchronization latency.</p>

<hr>

<h3>4. <strong>The Token Concurrency Optimization Hypothesis</strong></h3>
<p>Evaluating this trade-off establishes the core research question for multi-node admission control across varying token concurrency limits:</p>

<table border="1" cellpadding="6" cellspacing="0">
  <thead>
    <tr>
      <th>Token Concurrency Limit</th>
      <th>Network Contention State</th>
      <th>TCP Retransmissions</th>
      <th>Active Throughput</th>
      <th>Collective Barrier Time</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>1 Token (Strict Serial)</strong></td>
      <td>Zero Contention</td>
      <td>0 Retransmits</td>
      <td>90.14 Mbps (Max)</td>
      <td>9.05s (Extended by App Wait)</td>
    </tr>
    <tr>
      <td><strong>2 Tokens (Balanced Target)</strong></td>
      <td>Moderate Contention</td>
      <td>Low (Hypothesized)</td>
      <td>High (Shared Link)</td>
      <td><strong>Optimal Barrier Target (TBD)</strong></td>
    </tr>
    <tr>
      <td><strong>3 Tokens (Baseline Uncoordinated)</strong></td>
      <td>Severe Bottleneck Overflow</td>
      <td>408 Retransmits</td>
      <td>48.30 Mbps (Degraded)</td>
      <td>8.30s (Incast Constrained)</td>
    </tr>
  </tbody>
</table>

<hr>

<h1>Application Waiting vs Active Network Transfer</h1>
<p>Sequential token allocation created the following execution order and wall-clock finish times:</p>

<pre><code>Flow Execution & Finish Order:
1. Node 5201 ──► Granted: 0.00s ──► Active: 3.01s ──► Finished at 3.01s (90.15 Mbps)
2. Node 5203 ──► Granted: 2.42s ──► Active: 3.01s ──► Finished at 5.43s (90.13 Mbps)
3. Node 5202 ──► Granted: 6.04s ──► Active: 3.01s ──► Finished at 9.05s (90.14 Mbps)

Total Collective Wall-Clock Completion Time = 9.05 seconds
</code></pre>

<p>The GTL changes <strong>when the workload is admitted to the network socket</strong>, rather than simply increasing the physical network rate. Controlling admission concurrency isolates individual flows onto an unbuffered path, trading application queue time for loss-free network transmission.</p>

<hr>

<h1>Execution Flow Diagrams</h1>

<h2>Baseline (Uncoordinated)</h2>
<pre><code>3 simultaneous senders
        │
        ▼
Concurrent 270 Mbps offered load
        │
        ▼
100 Mbps TBF Bottleneck Queue
        │
        ▼
TCP Contention & Window Backoff
        │
        ▼
408 TCP Retransmissions (48.30 Mbps avg active rate)
        │
        ▼
Collective Barrier Completion Time: 8.30 seconds
</code></pre>

<h2>With ViYouna FCL / GTL (1 Token)</h2>
<pre><code>3 simultaneous senders
        │
        ▼
GTL Lease Request (UDP:5000)
        │
        ├──────────────► Node 5201 Granted (0.00s wait) ──► Active (3.01s) ──► Done at 3.01s
        │
        ├──────────────► Node 5203 Waits in RAM (2.42s)  ──► Active (3.01s) ──► Done at 5.43s
        │
        └──────────────► Node 5202 Waits in RAM (6.04s)  ──► Active (3.01s) ──► Done at 9.05s
        │
        ▼
Collective Barrier Completion Time: 9.05 seconds
</code></pre>

<hr>

<h1>Conclusion & Level 4 Roadmap</h1>

<h3>Current Validation Scope</h3>
<p>This software proof-of-concept demonstrates functional application-layer admission control (<strong>Level 1</strong>) and confirms that serializing socket ingress reduces transport-layer retransmissions under a controlled 100 Mbit/s virtual bottleneck (<strong>Levels 2 and 3</strong>).</p>

<h3>Next Steps (Level 4 Physical Validation)</h3>
<p>To evaluate whether FCL improves real-world AI workload performance, future physical hardware experiments will measure:</p>
<ul>
  <li><strong>Total Collective Barrier Completion Time</strong> across multi-token policies (1 vs 2 vs 3 tokens)</li>
  <li><strong>Direct Hardware Queue Drop Counters</strong> via <code>tc -s qdisc</code></li>
  <li><strong>Physical Switch ASIC Buffer Occupancy</strong></li>
  <li><strong>Statistical significance across N >= 30 randomized repetitions</strong></li>
</ul>

<hr>

<h1>Experimental Validation Levels</h1>
<pre><code>Level 1
  │
  └── Demonstrate GTL token lease lifecycle & idempotency
          │
          ▼
Level 2
  │
  └── Measure constrained path behavior
          │
          ▼
Level 3
  │
  └── Measure application-layer admission control (30MB single-run testbed)
          │
          ▼
Level 4
  │
  └── Measure Barrier Completion Time on physical switch ASICs
</code></pre>

<hr>

<h1>Reproducibility Statement</h1>
<p>This software testbed demonstrates the mechanics of application-layer admission control. The physical-network Level 4 experiment remains necessary to evaluate performance on real switch ASIC buffers and determine the impact on AI collective synchronization barriers.</p>
