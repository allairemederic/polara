# LDPC-Based ECC Integration in the POLARA RISC-V SoC

## Overview

This repository contains the integration of LDPC-based ECC into the L2 cache of the POLARA RISC-V SoC, including RTL integration, latency simulation, FPGA emulation, and performance benchmarks.

The target ECC configuration is an LDPC(144, 128) code, adding 16 parity bits to each 128-bit L2 cache data word.

Related projects
- [core-v-polara-apu](https://github.com/allairemederic/core-v-polara-apu)
- [GRM](https://github.com/PolyMTL-Gr2m)
- [Ara](https://github.com/PolyMTL-Gr2m/ara)
- [CVA6](https://github.com/PolyMTL-Gr2m/cva6)
- [OpenPiton](https://github.com/PrincetonUniversity/openpiton)

## Project Components

### FPGA Emulation

FPGA build configuration, resource-related modifications, and hardware validation for POLARA on a Xilinx Alveo U280.

### Latency Simulation

Configurable latency models used to evaluate ECC overhead before full integration, with ready/valid backpressure support.

### Benchmarks

FPGA benchmark flow for performance evaluation, including matrix multiplication and 2D convolution.

### ECC

LDPC(144,128) encoder/decoder RTL, generation and verification tools, and L2 cache integration.

### Results

Benchmark results comparing the baseline, simulated ECC latency, and integrated LDPC ECC configurations.