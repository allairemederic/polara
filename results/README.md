# Results

Contains the FPGA benchmark results collected for the different POLARA configurations evaluated in this project.

## Configurations

### Baseline

Reference POLARA configuration without additional ECC or simulated latency.

### Simulated latency

Results obtained by inserting artificial encoder and decoder latency into the L2 cache to evaluate the expected performance impact of ECC integration.

NoC latency
- Latency inserted around the NoC interface of the L2 cache pipe1 (read and partial write path)
- 1-cycle encoder latency before L2 cache pipe1 input buffer
- 3-cycle decoder latency after L2 cache pipe1 output buffer

L2 datapath with combinational encoder
- Latency inserted directly into the L2 datapath
- Combinational encoders placed in both pipe1 and pipe2
- 4-cycle decoder latency before L2 cache pipe1 output buffer

L2 datapath with 1-cycle encoder
- Latency inserted directly into the L2 datapath
- 1-cycle encoders placed in both pipe1 and pipe2
- 4-cycle decoder latency before L2 cache pipe1 output buffer

### LDPC ECC

Results obtained with the LDPC ECC architecture integrated into the L2 cache datapath.
- Combinational LDPC encoders integrated into both pipe1 and pipe2
- Pipelined LDPC decoder integrated into the L2 read datapath

## Analysis

The analyze_results.py script automatically parses and compares the benchmark results.

For each benchmark and test configuration, it:
1. Removes invalid executions (verify != 0 or cycles == 0)
2. Removes cycle-count outliers using the IQR method
3. Computes the median, mean, and standard deviation
4. Generates summary tables for each FPGA configuration
5. Compares each configuration against the baseline and calculates the performance variation
6. Generates comparison graphs