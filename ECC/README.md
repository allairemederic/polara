# LDPC ECC

LDPC-based ECC implementation for the POLARA L2 cache using an LDPC(144,128) code.

Each 128-bit L2 data word is encoded into a 144-bit codeword with 16 parity bits.

The `matrices` folder contains the LDPC matrices and config files used by the encoder and decoder.

## Encoder

SystemVerilog implementation of the LDPC encoder.

Includes:
- Combinational LDPC encoder
- L2 encoder wrapper used to integrate the encoder into the existing cache datapath
- Python generator used to generate the SystemVerilog parity matrix package
- Standalone verification against software-generated reference vectors
- Integration into the L2 `pipe1` and `pipe2` datapaths

## Decoder

Pipelined LDPC decoder used to decode L2 cache data.

Includes:
- LDPC decoder RTL
- L2 wrapper providing the interface between the decoder and the cache datapath
- Ready/valid backpressure support
- Standalone verification
- Integration into the L2 read datapath