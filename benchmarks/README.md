# Benchmarks

Integer benchmarks adapted from Ara and integrated into the POLARA FPGA flow:
- imatmul (integer matrix multiplication)
- iconv2d (integer 2D convolution)

Both use integer arithmetic, allowing execution with floating-point support disabled.

## Running the Benchmarks
 
[`run_benchmark_ddr.sh`](scripts/run_benchmark_ddr.sh) compiles the benchmark, boots POLARA, retrieves the DDR results, decodes them with [`decode_ddr.py`](scripts/decode_ddr.py), and saves the generated artifacts.

Run a benchmark with:

```bash
./run_benchmark_ddr.sh <benchmark.c>
```

Results are written to a dedicated DDR buffer and can also be decoded manually:

```bash
python3 decode_ddr.py <output_file>
```

## Integer Matrix Multiplication (imatmul)

64-bit integer matrix multiplication (`int64_t`):
- Matrix sizes: **4, 8, 16, 32, 64, 128**
- Iterations: **16 per size**
- Results: matrix size, execution cycles, and error status

Performance metrics are calculated offline to avoid floating-point operations on the FPGA.

## Integer 2D Convolution (iconv2d)

64-bit integer 2D convolution using **3×3, 5×5, and 7×7** filters.

[`iconv2d_output_ddr.c`](iconv2d_output_ddr.c)
- Output sizes: 64, 128, 256
- IFMAP dimensions are derived from the output and filter sizes

[`iconv2d_ifmap_ddr.c`](iconv2d_ifmap_ddr.c)
- IFMAP sizes: 64, 128, 256
- Output dimensions are derived from the IFMAP and filter sizes

## Known Limitations

Large matrices
- Matrix size 512 can stall iconv2d.
- Debugging of the 5×5 kernel narrowed the issue to `iconv2d_vec_4xC_5x5()`, around `vslidedown.vx` and `vmacc.vx`.

Multiple channels
- [`iconv2d_channels_ddr.c`](iconv2d_channels_ddr.c) works with one input channel but can stall with multiple channels.
- Exploring 3, 8. 16 channels could be interesting.