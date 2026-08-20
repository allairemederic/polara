# Benchmarks

The benchmarks are adapted from the integer benchmarks provided with the Ara vector processor and are integrated into the POLARA FPGA flow.

Two benchmarks are used:
- imatmul (integer matrix multiplication)
- iconv2d (integer 2D convolution)

Both use integer arithmetic only, allowing POLARA to run with floating-point support disabled.

## Running the Benchmarks

The run_benchmark_ddr.sh script handles the complete FPGA benchmark flow:
1. Configures and compiles the benchmark using rv64_cc and rv64_img
2. Generates the FPGA binary and boots POLARA
3. Retrieves the results from the DDR
4. Decodes the results using the script decode_ddr.py
5. Saves the source, logs, results and build artifacts in a dedicated run directory

Run a benchmark with:

./run_benchmark_ddr.sh <benchmark.c>

Results are written to a dedicated DDR buffer, allowing multiple measurements to be collected during a single execution.

Raw DDR results can also be decoded manually:

python3 decode_ddr.py <output_file>

## Integer Matrix Multiplication (imatmul)

Integer matrix multiplication using 64-bit data (int64_t):
- Matrix sizes: 4, 8, 16, 32, 64, 128
- Iterations per size: 16
- Recorded values: matrix size, execution cycles, and error status

Performance metrics are calculated offline to avoid floating-point operations on the FPGA.

## Integer 2D Convolution (iconv2d)

Integer 2D convolution using 3×3, 5×5, and 7×7 filters.

Two variants are used:

iconv2d_output_ddr.c
- Output sizes: 64, 128, 256
- IFMAP dimensions are derived from the output and filter sizes

iconv2d_ifmap_ddr.c
- IFMAP sizes: 64, 128, 256
- Output dimensions are derived from the IFMAP and filter sizes

## Known Limitations

Large iconv2d matrices
- Matrix dimensions of 512 can cause the benchmark to stall and are excluded from the main benchmark campaign.
- Debugging of the 5×5 kernel narrowed the stall down to iconv2d_vec_4xC_5x5(), around the loop using vslidedown.vx and vmacc.vx. The exact cause has not yet been identified.

Multiple input channels
- An experimental iconv2d_channels_ddr.c was developed to evaluate multiple input channels
- Single-channel configuration works correctly, but configurations with multiple channels can stall