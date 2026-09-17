# LDPC ECC

This directory contains the LDPC-based protection developed for the POLARA L2 cache.

The selected code uses the following configuration:

- Code length: 144 bits
- Information bits: 128 bits
- Parity bits: 16 bits
- Code rate: 0.889
- Decoder: Gallager-B
- Decoding iterations: 3

The code preserves the existing 144-bit L2 data-array width. Unlike the original implementation, which uses two independent SECDED blocks, the LDPC code protects the complete 128-bit data word.


## Components

- [Encoder](encoder/README.md): generates the protected codeword on both L2 write paths
- [Decoder](decoder/README.md): decodes the word on the pipe1 read path using a ready/valid interface
- [Matrices](matrices/): contains the LDPC configuration, generator matrix, and parity-check matrix
- [ECC Comparison](comparison-ldpc-secded/README.md): compares the recovery capability of the LDPC and SECDED implementations

## Configuration Files

The `.gen` matrix is used to generate the SystemVerilog encoder package, while the `.cfg` and `.al` files configure the VHDL decoder. Both implementations therefore use the same LDPC(144,128) code.

A valid codeword satisfies:

```text
H × cᵀ = 0