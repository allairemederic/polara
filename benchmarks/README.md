# Benchmarks

The following 64-bit integer benchmarks were adapted from Ara and integrated into the POLARA FPGA flow:

- [`imatmul_ddr.c`](imatmul_ddr.c): square matrix multiplication for sizes 4, 8, 16, 32, 64, and 128
- [`iconv2d_output_ddr.c`](iconv2d_output_ddr.c): 2D convolution with fixed output dimensions
- [`iconv2d_ifmap_ddr.c`](iconv2d_ifmap_ddr.c): 2D convolution with fixed input dimensions

The convolution benchmarks use 3×3, 5×5, and 7×7 filters with a stride of one, no padding, and one input channel. All benchmarks use `int64_t` arithmetic and can execute with floating-point support disabled.

## Running the Benchmarks
 
[`run_benchmark_ddr.sh`](scripts/run_benchmark_ddr.sh) compiles the program, boots POLARA, retrieves the results from DDR4, and decodes them using [`decode_ddr.py`](scripts/decode_ddr.py).


```bash
./run_benchmark_ddr.sh <benchmark.c>
```

Results are written to a dedicated DDR buffer and can also be decoded manually:

```bash
python3 decode_ddr.py <output_file>
```

## Known Limitations

- Some convolution configurations with a dimension of 512 can stall
- [`iconv2d_channels_ddr.c`](iconv2d_channels_ddr.c) works with one input channel but can stall with multiple channels.
- Multichannel configurations were not included in the reported experiments.