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

To test the wrapper with the mock top : 

- setenv SYN_HOME "/CMC/tools/synopsys/vcs_vT-2022.06-SP2/vcs/T-2022.06-SP2/"
- source /CMC/scripts/synopsys.vcs_verdi.2022.06-SP2.csh
- vcs -sverilog top_mock.sv L2_ecc_decoder_wrapper.sv tb_L2_ecc_decoder_wrapper.sv -top tb_L2_ecc_decoder_wrapper -o simv_ldpc_control
- ./simv_ldpc_control

To test the wrapper with the real top decoder : 

- setenv SYN_HOME "/CMC/tools/synopsys/vcs_vT-2022.06-SP2/vcs/T-2022.06-SP2/"
- source /CMC/scripts/synopsys.vcs_verdi.2022.06-SP2.csh
- setenv LDPC_HDL "/export/tmp/allaire/polara/core-v-polara-apu/ldpc_integration/gallager-b/hw/hdl"
- vhdlan -full64 \
    $LDPC_HDL/config_pkg.vhd  \
    $LDPC_HDL/utils_pkg.vhd \
    $LDPC_HDL/pipelineRegister.vhd \
    $LDPC_HDL/variableNodeUnit.vhd \
    $LDPC_HDL/checkNodeUnit.vhd \
    $LDPC_HDL/controlFlipFlop.vhd \
    $LDPC_HDL/info_fifo.vhd \
    $LDPC_HDL/pipelineBank_core.vhd \
    $LDPC_HDL/tannerGraphProcessor.vhd \
    $LDPC_HDL/GallagerB_core.vhd \
    $LDPC_HDL/top.vhd
- vcs -full64 -sverilog \
    -timescale=1ns/1ps \
    -debug_access+all \
    ../L2_ecc_decoder_wrapper.sv \
    tb_L2_ecc_decoder_wrapper.sv \
    -top tb_L2_ecc_decoder_wrapper \
    -o simv_ldpc_real
- ./simv_ldpc_real

