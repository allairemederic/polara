# LDPC-Based ECC Integration in the POLARA RISC-V SoC

## Overview

This repository documents the integration of LDPC-based error-correcting code (ECC) into the L2 cache of the POLARA RISC-V SoC. It includes the RTL integration, configurable latency models, FPGA emulation flow, verification tools, benchmarks, and experimental results.

The selected configuration is an LDPC(144,128) code that protects each 128-bit L2 cache data word with 16 parity bits.


## Repository Contents

- **FPGA Emulation:** POLARA build and hardware validation on a Xilinx Alveo U280
- **Latency Simulation:** configurable ECC latency models with ready/valid backpressure
- **Benchmarks:** integer matrix multiplication and 2D convolution benchmark flows
- **ECC:** LDPC encoder, decoder, verification tools, and L2 cache integration
- **Results:** baseline, simulated-latency, and integrated-ECC performance results

## Related projects

- [core-v-polara-apu](https://github.com/allairemederic/core-v-polara-apu)
- [GRM](https://github.com/PolyMTL-Gr2m)
- [Ara](https://github.com/PolyMTL-Gr2m/ara)
- [CVA6](https://github.com/PolyMTL-Gr2m/cva6)
- [OpenPiton](https://github.com/PrincetonUniversity/openpiton)

## Related Publications

### POLARA and Vector Processing

- [Conception physique d'un processeur vectoriel RISC-V multicœur avec une technologie avancée](https://polymtl.on.worldcat.org/oclc/1545047876)
- [Verification and Characterization of Multicore Vector Processors Enhanced for Low-precision Convolutional Layers Through FPGA Emulation](https://publications.polymtl.ca/58766/)
- [MSPARQ: A RISC-V Vector Processor Array Optimized for Low-Resolution Neural Networks](https://ieeexplore.ieee.org/document/10658697)
- [Sparq: A Custom RISC-V Vector Processor for Efficient Sub-Byte Quantized Inference](https://arxiv.org/abs/2306.09905)

### Fault Tolerance and LDPC Codes

- [Who Checks the Checker? Enhancing Component-level Architectural SEU Fault Tolerance for End-to-End SoC Protection](https://arxiv.org/abs/2603.26637)
- [LDPC Codes Which Can Correct Three Errors Under Iterative Decoding](https://arxiv.org/abs/0801.1282)