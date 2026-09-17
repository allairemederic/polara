# Exploration and Evaluation of LDPC Protection for the POLARA RISC-V SoC L2 Cache

## Overview

This repository presents the exploration and evaluation of LDPC-based protection for the L2 cache of the POLARA RISC-V SoC. It includes the RTL integration, configurable latency models, FPGA emulation flow, verification tools, integer benchmarks, and experimental results.

The selected LDPC(144,128) code protects each 128-bit L2 data word with 16 parity bits while preserving the cache existing 144-bit data-array width.

## Repository Structure

- [`fpga-emulation/`](fpga-emulation/): FPGA build configuration and hardware validation
- [`latency-simulation/`](latency-simulation/): configurable NoC and L2 datapath latency models
- [`ECC/`](ECC/): LDPC encoder, decoder, matrices, integration and verification
- [`benchmarks/`](benchmarks/): integer matrix multiplication and 2D convolution benchmarks
- [`results/`](results/): benchmark cycles, ILA counters, logic utilization and BER results

## Related Repositories

- [core-v-polara-apu](https://github.com/allairemederic/core-v-polara-apu)
- [GRM](https://github.com/PolyMTL-Gr2m)
- [Ara](https://github.com/PolyMTL-Gr2m/ara)
- [CVA6](https://github.com/PolyMTL-Gr2m/cva6)
- [OpenPiton](https://github.com/PrincetonUniversity/openpiton)

## Related Publications and Resources

- [Verification and Characterization of Multicore Vector Processors Enhanced for Low-precision Convolutional Layers Through FPGA Emulation](https://publications.polymtl.ca/58766/)
- [Conception physique d’un processeur vectoriel RISC-V multicœur avec une technologie avancée](https://polymtl.on.worldcat.org/oclc/1545047876)
- [MSPARQ: A RISC-V Vector Processor Array Optimized for Low-Resolution Neural Networks](https://ieeexplore.ieee.org/document/10658697)
- [Sparq: A Custom RISC-V Vector Processor for Efficient Sub-Byte Quantized Inference](https://arxiv.org/abs/2306.09905)
- [LDPC Codes Which Can Correct Three Errors Under Iterative Decoding](https://arxiv.org/abs/0801.1282)
- [OpenPiton Microarchitecture Specification](https://parallel.princeton.edu/open)