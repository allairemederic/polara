# LDPC-Based ECC Integration in the POLARA RISC-V SoC

## Overview

This repository contains the work done to integrate LDPC-based ECC into the L2 cache of the POLARA RISC-V SoC, including RTL integration, latency simulation, FPGA emulation, and performance benchmarks.

The target ECC configuration is an LDPC(144, 128) code, protecting each 128-bit L2 cache data word with 16 parity bits.

Related projects
- core-v-polara-apu : https://github.com/allairemederic/core-v-polara-apu
- GRM               : https://github.com/PolyMTL-Gr2m
- Ara               : https://github.com/PolyMTL-Gr2m/ara
- CVA6              : https://github.com/PolyMTL-Gr2m/cva6
- OpenPiton         : https://github.com/PrincetonUniversity/openpiton

## Architecture

... not finalized

## Project Components

FPGA Emulation
- Setup and modifications required to emulate POLARA on a Xilinx Alveo U280
- Includes the FPGA build configuration, resource-related modifications, and hardware validation

Latency Simulation
- Latency models used before integrating the complete LDPC decoder and encoder
- Includes latency insertion at different locations in the L2 pipeline
- Implementation supports backpressure to preserve the existing ready/valid behavior

Benchmarks
- Benchmarks used to validate the FPGA implementation and measure the performance impact of L2/ECC latency
- Includes scripts to build, run, and collect benchmark results
- Current benchmarks: matrix multiplication, 2D convolution

ECC
- RTL and integration work for the LDPC(144,128) ECC implementation
- Includes a SystemVerilog LDPC encoder, encoder package generation and verification
- Includes the LDPC decoder configuration and its integration in the L2 datapath

Results
- Contains the FPGA benchmark results for the different POLARA configurations evaluated in this project
- Includes baseline reference, simulated latency (around the NoC and in the datapath) and LDPC ECC