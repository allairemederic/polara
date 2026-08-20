# Benchmarks

The benchmarks are adapted from the integer benchmarks provided with the Ara vector processor and are integrated into the POLARA FPGA execution flow.

Two main benchmarks are used:
- imatmul (integer matrix multiplication)
- iconv2d (integer 2D convolution)

Both benchmarks use integer arithmetic only, allowing POLARA to be evaluated with floating-point support disabled.

## Running the Benchmarks

The run_benchmark_ddr.sh script handles the complete FPGA benchmark flow:
1. Sets the required POLARA configuration
2. Compiles the benchmark using rv64_cc and rv64_img
3. Converts the executable into the binary format required by the FPGA
4. Boots POLARA on the FPGA
5. Retrieves the benchmark results written to DDR
6. Decodes the benchmark results using decode_ddr.py
7. Saves the source file, logs, results and generated build artifacts in the run directory

Run a benchmark with:

./run_benchmark_ddr.sh <benchmark.c>

Benchmarks write their measurements to a dedicated DDR buffer instead of using UART, allowing multiple measurements to be collected during a single execution.

## Decoding the results

DDR results are stored in raw binary format and automatically decoded by run_benchmark_ddr.sh. They can also be decoded manually using:

python3 decode_ddr.py <output_file>

Depending on the benchmark, the decoded results contain the test configuration, execution cycle count, and error status.

Cycle counts can then be used to calculate performance metrics offline, such as operations per cycle and vector-lane utilization.

## Integer Matrix Multiplication (imatmul)

imatmul performs matrix multiplication using 64-bit integers (int64_t) and is used to evaluate the Ara vector unit and POLARA memory hierarchy under a compute-intensive workload.

Test configuration
- Matrix sizes: 4, 8, 16, 32, 64, 128
- Iterations per size: 16
- Recorded values: matrix size, execution cycles, and error status
- Performance metrics are calculated offline to avoid floating-point operations on the FPGA

## Integer 2D Convolution

iconv2d performs 2D convolution using 64-bit integer data with 3×3, 5×5, and 7×7 filters.

Two variants are used to independently evaluate the impact of input and output matrix dimensions.

Output-size benchmark (iconv2d_output_ddr.c)
- Output sizes: 64, 128, 256
- The IFMAP dimensions are automatically calculated from the output and filter sizes

IFMAP-size benchmark (iconv2d_ifmap_ddr.c)
- IFMAP sizes: 64, 128, 256
- The output dimensions are automatically calculated from the IFMAP and filter sizes

Separating the two experiments keeps each benchmark focused and avoids conditional test modes in the benchmark code.

## Known Limitations

Large iconv2d matrices
- Matrix dimensions of 512 can cause the benchmark to stall and are excluded from the main benchmark campaign
- Debugging of the 5×5 kernel narrowed the stall down to iconv2d_vec_4xC_5x5(), around the loop using vslidedown.vx and vmacc.vx. The exact cause has not yet been identified

Multiple input channels
- An experimental benchmark (iconv2d_channels_ddr.c) was developed to evaluate multiple input channels
- Single-channel configuration works correctly, but configurations with multiple channels can stall