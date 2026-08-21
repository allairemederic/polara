# Results

FPGA benchmark results for the different POLARA configurations evaluated in this project.

## Configurations

### Baseline

Reference POLARA configuration without ECC or additional latency.

### Simulated latency

Artificial encoder/decoder latency used to estimate the performance impact of ECC integration.

Configurations:
- NoC: 1-cycle encoder before the L2 pipe1 input bufer and 3-cycle decoder after its output buffer
- L2 datapath (combinational encoder): encoders in pipe1 and pipe2, with a 4-cycle decoder in pipe1
- L2 datapath (1-cycle encoder): 1-cycle encoders in pipe1 and pipe2, with a 4-cycle decoder in pipe1

### LDPC ECC

LDPC ECC integrated into the L2 datapath:
- Combinational LDPC encoders in pipe1 and pipe2
- Pipelined LDPC decoder in the pipe1 read path

## Analysis

The analyze_results.py script automatically:
1. Removes invalid results (verify != 0 or cycles == 0)
2. Removes outliers using the IQR method
3. Computes median, mean, and standard deviation
4. Generates summary and baseline-comparison tables
5. Generates comparison graphs