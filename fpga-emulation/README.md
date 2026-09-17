# FPGA Emulation

POLARA was emulated on a Xilinx Alveo U280 using a 2×2 tile configuration. The FPGA flow was used to validate system boot, UART communication, DDR4 accesses, and the execution of integer benchmarks.

## Build

Generate the reference image with:

```bash
protosyn --board alveou280 --design system --core ariane --x_tiles 2 --y_tiles 2 --jobs 16 --defines NO_FPU_SUPPORT
```

Floating-point support is disabled to reduce resource utilization. See [FPU.md](FPU.md) for the required CVA6 and Ara modifications.

### Compilation Macros

These macros are used to configure the POLARA FPGA build:
- `NO_FPU_SUPPORT` : disables floating-point support
- `SIMULATE_LDPC_LATENCY` : enables artificial encoder and decoder latency in the L2 cache
- `USE_LDPC_ECC` : Enables the LDPC-based ECC implementation in the L2 cache
- `DEBUG_L2_DELAY_BUFFER`: enables transaction and stall counters for ILA debugging

## Hardware Validation

### UART Boot Test

[`uart_hello_world.c`](tests/uart_hello_world.c) verifies that POLARA boots correctly and that UART output is functional.

```bash
./tests/run_uart_test.sh tests/uart_hello_world.c
```

### DDR Access Test

[`ddr_writing_test.c `](tests/ddr_writing_test.c )writes test values to DDR4 from POLARA. The resulting memory contents are then read back from the host and compared with the expected values.

```bash
./tests/run_ddr_test.sh tests/ddr_writing_test.c
```