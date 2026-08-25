<p><strong>#ViYouna #GTL #DCOP #FCL-Proof</strong></p>
<h4>by Mohammad Tayyebi</h4>
<h1>Experimental Validation: Software-Based Ingress Coordination Eliminates TCP Retransmissions and Doubles Active Throughput</h1>

<h3>The Objective</h3>
<p>To empirically validate that application-layer pre-transmission coordination (the Fabric Coordination Layer) can completely mitigate network incast, eliminate TCP retransmissions, and double active flow throughput in synchronized AI workloads without requiring proprietary network hardware.</p>

<h3>The Architecture</h3>
<ul>
<li><strong>3 Sender Nodes:</strong> Simulating a GPU compute cluster executing simultaneous collective data bursts.</li>
<li><strong>1 Receiver Node:</strong> Providing a controlled constrained network path (100 Mbit/s bottleneck).</li>
<li><strong>ViYouna GTL:</strong> A software-based Global Token Ledger governing network ingress authority over UDP port 5000.</li>
</ul>

<h2>Architecture Topology</h2>
<ul>
<li><strong>GTL Server (<code>gtl-server</code>):</strong> Central token ledger managing application admission tokens.</li>
<li><strong>Sender VMs (<code>sender-1</code>, <code>sender-2</code>, <code>sender-3</code>):</strong> Distributed compute nodes executing parallel TCP workloads.</li>
<li><strong>Receiver VM (<code>receiver</code>):</strong> Ingress destination configured with a controlled 100 Mbit/s Linux Traffic Control (<code>tbf</code>) bottleneck queue.</li>
</ul>

<hr>

<h3>Methodology & Testbed Setup</h3>
<p>To create a controlled network bottleneck, we built a virtualized micro-data center using Canonical Multipass with Hyper-V.</p>

<p><strong>1. Level 1 & 2 Validation: Queue Constraint & Retransmissions</strong></p>
<p>We use Linux Traffic Control (<code>tc</code>) to create a controlled software bottleneck that limits the ingress traffic path to <strong>100 Mbit/s</strong> with a <code>1mbit burst / 5mbit limit</code> queue buffer on an Intermediate Functional Block (<code>ifb0</code>) interface.</p>
<p>The purpose is to create a repeatable constrained queue for experimentation rather than claiming that the Linux queue is identical to a physical switch ASIC buffer.</p>
<p>We then generate concurrent TCP bursts across 3 Senders using <code>iperf3</code> to measure transfer behavior, socket throughput, and kernel-reported TCP retransmissions under uncoordinated contention.</p>

<p><strong>2. Level 3 Validation: Coordination & Pacing</strong></p>
<p>We wrapped a fixed TCP payload inside our proprietary ViYouna workload script.</p>
<p>The script polls the GTL (configured with a strict concurrency limit of 1 token) before allowing the workload to transmit over the socket. When no token is available, the workload waits in host application memory rather than immediately injecting another burst into the constrained network path.</p>
<p>This provides a software-level demonstration of deterministic, application-layer ingress pacing.</p>

<hr>

<h1>How to Run This Proof of Concept (Quick Start Guide)</h1>

<h2>1. Prerequisites</h2>
<p>Install Canonical Multipass. This setup is designed for Multipass environments using Windows Hyper-V, macOS, or Linux.</p>

<hr>

<h2>2. Automated One-Command Cluster Setup</h2>
<p>Instead of manually configuring IP tables and background daemons across 5 VMs, execute the automated deployment script from PowerShell:</p>
<pre><code>.\setup.ps1</code></pre>
<p>This automated script will:</p>
<ol>
<li>Launch all 5 lightweight Ubuntu VMs (<code>gtl-server</code>, <code>receiver</code>, <code>sender-1..3</code>).</li>
<li>Install all system dependencies (<code>python3</code>, <code>iperf3</code>, <code>iproute2</code>).</li>
<li>Deploy <code>workload.py</code> and <code>gtl_server.py</code> to their respective nodes.</li>
<li>Automatically redirect <code>eth0</code> ingress on the receiver to an <code>ifb0</code> interface and apply the 100 Mbit/s Token Bucket Filter (TBF).</li>
<li>Initialize the <code>iperf3</code> server daemons and run the GTL server as a persistent <code>systemd</code> daemon.</li>
</ol>

<hr>

<h2>3. Run the Automated Dual Benchmark</h2>
<p>Execute the orchestrator from PowerShell, specifying 1 GTL token:</p>
<pre><code>.\run_benchmark.ps1 1</code></pre>
<p>The orchestrator guarantees clean measurements by:</p>
<ul>
<li>resetting the receiver queue state and daemons before every test;</li>
<li>clearing stale <code>/tmp/metrics.json</code> files;</li>
<li>restarting the GTL server with the target token parameter;</li>
<li>running the <strong>Baseline (Uncoordinated)</strong> and <strong>FCL Coordinated</strong> runs sequentially;</li>
<li>formatting verified telemetry directly from <code>iperf3</code> JSON kernel output.</li>
</ul>

<hr>

<h1>Empirical Telemetry Results</h1>
<p>Empirical telemetry gathered across 3 concurrent sender flows over the reported 100 Mbit/s constrained link:</p>

<table border="1" cellpadding="8" cellspacing="0">
  <thead>
    <tr>
      <th>Node / Port</th>
      <th>GTL Mode</th>
      <th>App Wait Time</th>
      <th>Active Transfer Time</th>
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
      <td>43.15 Mbps</td>
      <td>68</td>
      <td>TCP Retransmissions Observed</td>
    </tr>
    <tr>
      <td><strong>Node 5201</strong></td>
      <td><strong>With GTL (1 Token)</strong></td>
      <td><strong>0.00s</strong></td>
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
      <td>58.90 Mbps</td>
      <td>334</td>
      <td>TCP Retransmissions Observed</td>
    </tr>
    <tr>
      <td><strong>Node 5202</strong></td>
      <td><strong>With GTL (1 Token)</strong></td>
      <td><strong>6.04s</strong></td>
      <td><strong>3.01s</strong></td>
      <td><strong>90.14 Mbps</strong></td>
      <td><strong>0</strong></td>
      <td><strong>Application Paced</strong></td>
    </tr>
    <tr>
      <td><strong>Node 5203</strong></td>
      <td>Without GTL</td>
      <td>0.00s</td>
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
      <td><strong>90.13 Mbps</strong></td>
      <td><strong>0</strong></td>
      <td><strong>Application Paced</strong></td>
    </tr>
  </tbody>
</table>

<hr>

<h1>Key Experimental Insights</h1>

<h3>1. <strong>+86.6% Throughput Gain per Active Flow</strong></h3>
<p>Baseline average throughput:<br>
<code>(43.15 + 58.90 + 42.86) / 3 = 48.30 Mbps</code></p>
<p>Coordinated average active throughput:<br>
<code>90.14 Mbps</code></p>
<p>Calculated gain:<br>
<code>(90.14 / 48.30 - 1) * 100 = +86.6%</code></p>
<p><strong>Result: Approximately +86.6% average throughput per active flow in the recorded benchmark, fully saturating the configured target rate.</strong></p>

<hr>

<h3>2. <strong>-53.6% Active Transfer Time</strong></h3>
<p>Baseline average active transfer time:<br>
<code>(6.06 + 5.11 + 8.30) / 3 = 6.49 seconds</code></p>
<p>Coordinated active transfer time:<br>
<code>3.01 seconds</code></p>
<p>Calculated reduction:<br>
<code>(1 - 3.01 / 6.49) * 100 = 53.6%</code></p>
<p><strong>Result: Approximately -53.6% average active transfer time per flow under GTL coordination.</strong></p>

<hr>

<h3>3. <strong>-100% TCP Retransmission Elimination</strong></h3>
<p>Baseline total TCP retransmissions:<br>
<code>68 + 334 + 6 = 408 retransmissions</code></p>
<p>Coordinated total TCP retransmissions:<br>
<code>0 + 0 + 0 = 0 retransmissions</code></p>
<p>Calculated reduction:<br>
<code>100% complete elimination of packet retransmissions</code></p>

<blockquote>
  <p>This experiment directly measures kernel-reported <strong>TCP retransmissions</strong>. FCL completely eliminates buffer overflows and queue drops by ensuring no two flows contend for the constrained queue simultaneously.</p>
</blockquote>

<hr>

<h1>Application Waiting vs Active Network Transfer</h1>
<p>The coordinated run demonstrates a clear operational separation between:</p>
<ul>
<li><strong>Application Wait Time (Pacing in RAM)</strong></li>
<li><strong>Active Network Transfer Time (Clean Pipe Execution)</strong></li>
</ul>
<p>For example:</p>
<pre><code>Node 5202
GTL Wait Time:    6.04 seconds
Active Transfer:  3.01 seconds
Throughput:       90.14 Mbps (0 Retransmissions)
</code></pre>
<p>The GTL changes <strong>when the workload is admitted to the network socket</strong>, preventing TCP CUBIC congestion collapse and maintaining maximum line-rate transmission once admitted.</p>

<hr>

<h1>Experimental Validation Summary</h1>

<h2>Baseline (Uncoordinated)</h2>
<pre><code>3 simultaneous senders
        │
        ▼
Uncoordinated TCP bursts
        │
        ▼
Controlled constrained queue (100 Mbps)
        │
        ▼
Queue overflow & contention
        │
        ▼
408 TCP retransmissions & TCP window collapse (~48 Mbps average)
</code></pre>

<h2>With ViYouna FCL / GTL (1 Token)</h2>
<pre><code>3 simultaneous senders
        │
        ▼
GTL token coordination (UDP:5000)
        │
        ├──────────────► Flow 1 Admitted ──► Clean Pipe (90.15 Mbps / 0 Retransmissions)
        │
        ├──────────────► Flow 2 Waits in RAM (2.42s) ──► Admitted ──► Clean Pipe (90.13 Mbps)
        │
        └──────────────► Flow 3 Waits in RAM (6.04s) ──► Admitted ──► Clean Pipe (90.14 Mbps)
</code></pre>

<hr>

<h1>Conclusion & Next Steps</h1>

<h3>Current Validation</h3>
<p>This Proof of Concept demonstrates functional application-layer ingress coordination (<strong>Level 1</strong>) and provides empirical evidence that the coordination mechanism completely eliminates TCP retransmissions and maximizes active link throughput under a controlled software bottleneck (<strong>Levels 2 and 3</strong>).</p>

<h3>Next Steps (Level 4 Validation)</h3>
<p>The current environment is a virtualized Multipass/Hyper-V testbed.</p>
<p>Because virtualized networking involves host and virtual-switch processing, this experiment does not establish the exact behavior of a physical data-center switch ASIC under hardware RoCE v2 / PFC conditions.</p>
<p>The next phase of this project will execute the FCL architecture across physical switch hardware and measure:</p>
<ul>
<li><strong>Barrier Completion Time</strong></li>
<li><strong>Collective Completion Time</strong></li>
<li><strong>Per-flow TCP Retransmissions</strong></li>
<li><strong>Hardware queue ASIC depth and buffer occupancy</strong></li>
<li><strong>AI workload synchronization delay / GPU Straggler Tax</strong></li>
</ul>

<hr>

<h1>Current Project Status</h1>
<ul>
<li><strong>Current Level:</strong> Level 1–3 Proof of Concept</li>
<li><strong>Environment:</strong> Canonical Multipass + Hyper-V</li>
<li><strong>Nodes:</strong> 3 Senders + 1 Receiver + 1 GTL Server</li>
<li><strong>Traffic:</strong> Concurrent TCP workloads</li>
<li><strong>Controlled Bottleneck:</strong> 100 Mbit/s Linux traffic-control path</li>
<li><strong>Coordination Mechanism:</strong> ViYouna Global Token Ledger (GTL)</li>
<li><strong>Primary Measurements:</strong> TCP retransmissions, application wait time, active transfer time, and throughput</li>
<li><strong>Recorded Benchmark Result:</strong> 0 TCP retransmissions, +86.6% active throughput gain, -53.6% active transfer time</li>
<li><strong>Next Validation Target:</strong> Physical switch ASICs and direct measurement of AI collective Barrier Completion Time</li>
</ul>

<hr>

<h1>Experimental Validation Levels</h1>
<pre><code>Level 1
  │
  └── Demonstrate GTL token acquisition and release
          │
          ▼
Level 2
  │
  └── Demonstrate constrained network behavior
          │
          ▼
Level 3
  │
  └── Demonstrate application-layer pacing (Zero Retransmissions / 90 Mbps Saturation)
          │
          ▼
Level 4
  │
  └── Validate behavior on physical switch ASICs
          │
          ▼
Measure true AI collective Barrier Completion Time and GPU Straggler Tax
</code></pre>

<hr>

<h1>Reproducibility Statement</h1>
<p>The Level 1–3 experiment is intended as a <strong>controlled software proof of concept</strong>.</p>
<p>The experiment demonstrates the mechanism of application-layer coordination and provides recorded measurements of TCP retransmissions, throughput, active transfer time, and application waiting behavior.</p>
<p>The physical-network Level 4 experiment remains necessary to validate the proposed effect on real switch queues and to establish the relationship between FCL coordination and AI collective synchronization time.</p>
