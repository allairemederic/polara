# FPGA Emulation

POLARA was emulated on a Xilinx Alveo U280 using a 2×2 tile configuration.

## Build

- Board: Xilinx Alveo U280
- Core: CVA6/Ariane
- Tiles: 2×2
- ProtoSyn: v2.5

Generate the image with:

```bash
protosyn --board alveou280 --design system --core ariane --x_tiles 2 --y_tiles 2 --jobs 16 --define NO_FPU_SUPPORT
```

Floating-point support is disabled to reduce resource utilization. See [no-fpu.md](no-fpu.md) for the required CVA6 and Ara modifications.

### Compilation Macros

These macros are used to configure the POLARA FPGA build:
- NO_FPU_SUPPORT : disables floating-point support
- SIMULATE_LDPC_LATENCY : enables artificial encoder and decoder latency in the L2 cache
- USE_LDPC_ECC : Enables the LDPC-based ECC implementation in the L2 cache

## Tests

### UART Hello World

[`uart_hello_world.c`](tests/uart_hello_world.c) verifies that POLARA boots correctly and that UART output is functional.

```bash
./tests/run_uart_test.sh tests/uart_hello_world.c
```

### DDR Writing Test

[`ddr_writing_test.c `](tests/ddr_writing_test.c )verifies DDR accesses by writing values from POLARA and reading them back from the host.

```bash
./tests/run_ddr_test.sh tests/ddr_writing_test.c
```