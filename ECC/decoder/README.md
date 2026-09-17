# LDPC Decoder

The decoder restores the 128-bit data word from a 144-bit LDPC codeword using a three-iteration Gallager-B implementation.

## Interface

The VHDL decoder uses a ready/valid interface:

- `I_channelBits`: 144-bit input codeword
- `O_decodedBits`: 128-bit decoded data
- `I_input_valid` / `O_input_ready`: input handshake
- `O_output_valid` / `I_output_ready`: output handshake

[`L2_ecc_decoder_wrapper.sv`](L2_ecc_decoder_wrapper.sv) connects this interface to the POLARA L2 pipeline.

## Integration

The decoder is inserted after the L2 data-array read in pipe1. Stage S4 remains stalled until the decoded output becomes valid.

See [L2 datapath integration](datapath-decoder-integration.md).

## Verification

- `top_tb.vhd`: verifies nominal decoding
- `top_stall_test_tb.vhd`: verifies output stability and backpressure