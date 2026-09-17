# Results

This directory contains the experimental results collected for the POLARA FPGA configurations evaluated in this project.

## Configurations

- **Baseline:** original SECDED protection without additional latency
- **NoC delay:** one-cycle input delay and three-cycle output delay around pipe1
- **Datapath delay:** four-cycle delay in the pipe1 read path
- **LDPC ECC:** combinational encoders and pipelined Gallager-B decoder

## Result Categories

### Benchmark Cycles

[`cycles/`](cycles/) contains the raw execution-cycle measurements for `imatmul` and `iconv2d`.

[`analyze_results.py`](analyze_results.py):

1. removes results where `verify != 0` or `cycles == 0`;
2. removes outliers using the IQR method;
3. computes the median, mean, and standard deviation;
4. generates comparison tables and figures.

### Buffer Activity

[`buffer/`](buffer/) contains the ILA counter values collected from `L2_delay_buffer`:

- accepted transactions;
- input stall cycles;
- output stall cycles.

### Logic Utilization

[`logic-utilization/`](logic-utilization/) contains the post-implementation LUT, FF, BRAM, and DSP utilization reported by Vivado.

### Error-Correction Performance

[`BER/`](BER/) contains the residual BER values used to compare the SECDED and LDPC protections.