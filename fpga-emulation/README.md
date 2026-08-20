# FPGA Emulation

POLARA was emulated on a Xilinx Alveo U280 using a 2×2 tile configuration.

## Build

Configuration
- Board: Xilinx Alveo U280
- Core: CVA6/Ariane
- Tiles: 2×2
- ProtoSyn: v2.5
- Floating-point support: disabled

### ProtoSyn

The FPGA image can be generated from the POLARA repository using:

protosyn --board alveou280 --design system --core ariane --x_tiles 2 --y_tiles 2 --jobs 16 --define NO_FPU_SUPPORT

Floating-point support was disabled to reduce FPGA resource utilization. The required CVA6 and Ara modifications are documented in no-fpu.md.

## Tests

Basic tests are provided to verify that the generated FPGA image boots correctly and that the main interfaces required by the benchmarks are functional.

UART Hello World
- tests/uart_hello_world.c
- Basic software test used to verify that POLARA successfully boots on the FPGA and that UART output is functional
- The complete test flow is automated by: ./tests/run_uart_test.sh tests/uart_hello_world.c

DDR Writing Test
- tests/ddr_writing_test.c
- Tests accesses to the FPGA DDR memory by writing known values from POLARA and reading the corresponding memory region back through the host
- The complete test flow is automated by: ./tests/run_ddr_test.sh tests/ddr_writing_test.c