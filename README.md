<h1>Mohammad-Tayyebi</h1>
<p><strong>#ViYouna #GTL #DCOP #FCL-Proof</strong></p>

<h1>Experimental Validation: Software-Based Ingress Coordination Reduces TCP Retransmissions</h1>

<h3>The Objective</h3>
<p>To empirically validate that application-layer pre-transmission coordination (the Fabric Coordination Layer) can mitigate network incast and reduce TCP retransmissions in synchronized AI workloads, without requiring proprietary network hardware.</p>

<h3>The Architecture</h3>
<ul>
<li><strong>3 Sender Nodes:</strong> Simulating a GPU cluster executing simultaneous collective bursts.</li>
<li><strong>1 Receiver Node:</strong> Providing a controlled constrained network path.</li>
<li><strong>ViYouna GTL:</strong> A software-based Global Token Ledger governing network ingress authority.</li>
</ul>

<h2>Architecture Topology</h2>
<ul>
<li><strong>GTL Server (<code>gtl-server</code>):</strong> Central token ledger running on UDP port 5000.</li>
<li><strong>Sender VMs (<code>sender-1</code>, <code>sender-2</code>, <code>sender-3</code>):</strong> Compute nodes executing parallel 100MB workloads.</li>
<li><strong>Receiver VM (<code>receiver</code>):</strong> Ingress destination configured with a controlled 100 Mbit/s Linux traffic-control bottleneck.</li>
</ul>

<hr>

<h3>Methodology & Testbed Setup</h3>
<p>To create a controlled network bottleneck, we built a virtualized micro-data center using Canonical Multipass with Hyper-V.</p>

<p><strong>1. Level 1 & 2 Validation: Queue Constraint & Retransmissions</strong></p>
<p>We use Linux traffic control to create a controlled software bottleneck that limits the traffic path to approximately <strong>100 Mbit/s</strong>.</p>
<p>The purpose is to create a repeatable constrained queue for experimentation rather than to claim that the Linux queue is identical to a physical switch ASIC buffer.</p>
<p>We then use <code>iperf3</code> to generate simultaneous TCP traffic from the 3 Senders and measure the resulting transfer behavior and TCP retransmissions.</p>

<p><strong>2. Level 3 Validation: Coordination & Pacing</strong></p>
<p>We wrapped a fixed TCP payload inside our proprietary ViYouna workload script.</p>
<p>The script polls the GTL, which is configured with a strict concurrency limit, before allowing the workload to transmit. When no token is available, the workload waits in application memory rather than immediately injecting another burst into the constrained network path.</p>
<p>This provides a software-level demonstration of deterministic, application-layer ingress pacing.</p>

<hr>

<h1>How to Run This Proof of Concept (Quick Start Guide)</h1>

<h2>1. Prerequisites</h2>
<p>Install Canonical Multipass.</p>
<p>This setup is designed for Multipass environments using Windows Hyper-V, macOS, or Linux.</p>

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
<li>Initialize the <code>iperf3</code> server daemons and run the GTL server in the background.</li>
</ol>

<hr>

<h2>3. Run the Automated Dual Benchmark</h2>
<p>Execute the bulletproof orchestrator from PowerShell:</p>
<pre><code>.\run_benchmark.ps1</code></pre>
<p>The orchestrator guarantees clean measurements by:</p>
<ul>
<li>resetting the receiver queue state and daemons before every test;</li>
<li>clearing stale <code>/tmp/metrics.json</code> files;</li>
<li>sending a forced <code>reset</code> signal to restore GTL token counts;</li>
<li>running the <strong>Baseline (Uncoordinated)</strong> and <strong>FCL Coordinated</strong> runs sequentially;</li>
<li>formatting verified telemetry directly from <code>iperf3</code> JSON kernel output.</li>
</ul>

<hr>

<h1>Empirical Results</h1>
<p>Empirical telemetry gathered across 3 concurrent 100MB sender flows over the reported 100 Mbit/s constrained link:</p>

<table border="1">
  <thead>
    <tr>
      <th>Node / Port</th>
      <th>Mode</th>
      <th>Wait Time</th>
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
      <td>26.02s</td>
      <td>32.26 Mbps</td>
      <td>6,070</td>
      <td>High Congestion</td>
    </tr>
    <tr>
      <td><strong>Node 5201</strong></td>
      <td><strong>With GTL</strong></td>
      <td><strong>0.00s</strong></td>
      <td><strong>11.03s</strong></td>
      <td><strong>76.25 Mbps</strong></td>
      <td><strong>4,759</strong></td>
      <td>Application Paced</td>
    </tr>
    <tr>
      <td><strong>Node 5202</strong></td>
      <td>Without GTL</td>
      <td>0.00s</td>
      <td>27.02s</td>
      <td>31.07 Mbps</td>
      <td>6,399</td>
      <td>High Congestion</td>
    </tr>
    <tr>
      <td><strong>Node 5202</strong></td>
      <td><strong>With GTL</strong></td>
      <td><strong>11.19s</strong></td>
      <td><strong>11.03s</strong></td>
      <td><strong>76.25 Mbps</strong></td>
      <td><strong>4,775</strong></td>
      <td>Application Paced</td>
    </tr>
    <tr>
      <td><strong>Node 5203</strong></td>
      <td>Without GTL</td>
      <td>0.00s</td>
      <td>27.02s</td>
      <td>31.06 Mbps</td>
      <td>6,219</td>
      <td>High Congestion</td>
    </tr>
    <tr>
      <td><strong>Node 5203</strong></td>
      <td><strong>With GTL</strong></td>
      <td><strong>21.17s</strong></td>
      <td><strong>11.03s</strong></td>
      <td><strong>76.25 Mbps</strong></td>
      <td><strong>4,691</strong></td>
      <td>Application Paced</td>
    </tr>
  </tbody>
</table>

<hr>

<h1>Key Experimental Insights</h1>

<h3>1. <strong>+142% Throughput Gain per Active Flow</strong></h3>
<p>Baseline average throughput:<br>
(32.26 + 31.07 + 31.06) / 3 = 31.46 Mbps</p>
<p>Coordinated average throughput:<br>
76.25 Mbps</p>
<p>Calculated gain:<br>
(76.25 / 31.46 - 1) * 100 = 142.3%</p>
<p><strong>Result: Approximately +142% average throughput per active flow in the recorded benchmark.</strong></p>

<hr>

<h3>2. <strong>-58.7% Active Transfer Time</strong></h3>
<p>Baseline average active transfer time:<br>
(26.02 + 27.02 + 27.02) / 3 = 26.69 seconds</p>
<p>Coordinated active transfer time:<br>
11.03 seconds</p>
<p>Calculated reduction:<br>
(1 - 11.03 / 26.69) * 100 = 58.7%</p>
<p><strong>Result: Approximately -58.7% average active transfer time in the recorded benchmark.</strong></p>

<hr>

<h3>3. <strong>-23.9% TCP Retransmissions</strong></h3>
<p>Baseline mean TCP retransmissions:<br>
(6070 + 6399 + 6219) / 3 = 6229.3</p>
<p>Coordinated mean TCP retransmissions:<br>
(4759 + 4775 + 4691) / 3 = 4741.7</p>
<p>Calculated reduction:<br>
(1 - 4741.7 / 6229.3) * 100 = 23.9%</p>
<p><strong>Result: Approximately -23.9% mean TCP retransmissions in the recorded benchmark.</strong></p>

<blockquote>
  <p>This experiment directly measures <strong>TCP retransmissions</strong>, not packet loss itself. Therefore the result is reported as a reduction in TCP retransmissions rather than as a direct packet-loss reduction.</p>
</blockquote>

<hr>

<h1>Application Waiting vs Active Network Transfer</h1>
<p>The coordinated run demonstrates a separation between:</p>
<ul>
<li><strong>Application Wait Time</strong></li>
<li><strong>Active Network Transfer Time</strong></li>
</ul>
<p>For example:</p>
<pre><code>Node 5203
GTL Wait Time:    21.17 seconds
Active Transfer:  11.03 seconds
</code></pre>
<p>The GTL changes <strong>when the workload is admitted to the network</strong>, rather than simply increasing the physical network rate.</p>
<p>This distinction is important for future AI collective experiments because <strong>individual flow completion time is not the same measurement as collective barrier completion time</strong>.</p>

<hr>

<h1>Conclusion & Next Steps</h1>

<h3>Current Validation</h3>
<p>This Proof of Concept demonstrates functional application-layer ingress coordination (<strong>Level 1</strong>) and provides empirical evidence that the coordination mechanism can reduce TCP retransmissions under a controlled software bottleneck (<strong>Levels 2 and 3</strong>).</p>
<p>The current experiment demonstrates:</p>
<ul>
<li><strong>Software token coordination</strong></li>
<li><strong>Application-layer admission control</strong></li>
<li><strong>Application-level waiting before transmission</strong></li>
<li><strong>Reduced TCP retransmissions in the recorded benchmark</strong></li>
<li><strong>Reduced active transfer time for the recorded coordinated flows</strong></li>
</ul>

<h3>Next Steps (Level 4 Validation)</h3>
<p>The current environment is a virtualized Multipass/Hyper-V testbed.</p>
<p>Because virtualized networking can involve host and virtual-switch processing, this experiment does not establish the exact behavior of a physical data-center switch ASIC.</p>
<p>The next phase of this project will execute the FCL architecture across physical switch hardware and measure:</p>
<ul>
<li><strong>Barrier Completion Time</strong></li>
<li><strong>Collective Completion Time</strong></li>
<li><strong>Per-flow TCP Retransmissions</strong></li>
<li><strong>Aggregate TCP Retransmissions</strong></li>
<li><strong>Queue behavior</strong></li>
<li><strong>Network utilization</strong></li>
<li><strong>AI workload synchronization delay</strong></li>
<li><strong>GPU Straggler Tax</strong></li>
</ul>
<p>The goal of Level 4 is to determine whether the application-layer coordination demonstrated here produces a measurable reduction in real AI collective synchronization time on physical switch infrastructure.</p>

<hr>

<h1>Experimental Validation Summary</h1>

<h2>Baseline</h2>
<pre><code>3 simultaneous senders
        │
        ▼
Uncoordinated TCP bursts
        │
        ▼
Controlled constrained queue
        │
        ▼
Contention
        │
        ▼
TCP retransmissions
</code></pre>

<h2>With ViYouna FCL / GTL</h2>
<pre><code>3 simultaneous senders
        │
        ▼
GTL token coordination
        │
        ├──────────────► Active flow
        │
        ├──────────────► Active flow
        │
        └──────────────► Wait in application memory
                               │
                               ▼
                         Token released
                               │
                               ▼
                         TCP transmission
                               │
                               ▼
                      Reduced contention
</code></pre>

<hr>

<h1>Current Project Status</h1>
<ul>
<li><strong>Current Level:</strong> Level 1–3 Proof of Concept</li>
<li><strong>Environment:</strong> Canonical Multipass + Hyper-V</li>
<li><strong>Nodes:</strong> 3 Senders + 1 Receiver + 1 GTL Server</li>
<li><strong>Traffic:</strong> Concurrent 100MB TCP workloads</li>
<li><strong>Controlled Bottleneck:</strong> 100 Mbit/s Linux traffic-control path</li>
<li><strong>Coordination Mechanism:</strong> ViYouna Global Token Ledger (GTL)</li>
<li><strong>Primary Measurements:</strong> TCP retransmissions, application wait time, transfer time, and throughput</li>
<li><strong>Recorded Benchmark Result:</strong> Lower TCP retransmissions and shorter active transfer times under GTL coordination</li>
<li><strong>Next Validation Target:</strong> Physical switch ASICs and direct measurement of AI collective Barrier Completion Time / Straggler Tax</li>
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
  └── Demonstrate application-layer pacing
          │
          ▼
Level 4
  │
  └── Validate behavior on physical switch ASICs
          │
          ▼
Measure true AI collective
Barrier Completion Time
and Straggler Tax
</code></pre>

<hr>

<h1>Reproducibility Statement</h1>
<p>The Level 1–3 experiment is intended as a <strong>controlled software proof of concept</strong>.</p>
<p>The experiment demonstrates the mechanism of application-layer coordination and provides recorded measurements of TCP retransmissions, throughput, transfer time, and application waiting behavior.</p>
<p>The physical-network Level 4 experiment remains necessary to validate the proposed effect on real switch queues and to establish the relationship between FCL coordination and AI collective synchronization time.</p>
