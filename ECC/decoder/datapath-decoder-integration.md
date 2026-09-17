# LDPC Decoder Integration

The LDPC decoder replaces the two combinational SECDED decoders in the pipe1 read path when `USE_LDPC_ECC` is enabled.

It receives the 144-bit codeword from `data_data_trans_S4` and returns the decoded 128-bit data word. Because decoding requires multiple cycles, stage S4 remains stalled until the output becomes valid.

## Decoder Configuration

Generate `config_pkg.vhd` from the selected LDPC configuration:

```bash
python3 configPackage.py <ldpc_configuration.cfg>
```

The encoder and decoder must use matrices generated from the same LDPC configuration.

## Source Organization

Place the Gallager-B repository in an `ldpc_integration` directory alongside the `piton` directory:

```text
project/
├── piton/
└── ldpc_integration/
    └── gallager-b/
        └── hw/
            └── hdl/
                ├── utils_pkg.vhd
                ├── config_pkg.vhd
                ├── pipelineRegister.vhd
                ├── variableNodeUnit.vhd
                ├── checkNodeUnit.vhd
                ├── controlFlipFlop.vhd
                ├── info_fifo.vhd
                ├── pipelineBank_core.vhd
                ├── tannerGraphProcessor.vhd
                ├── GallagerB_core.vhd
                └── top.vhd
```

## RTL Source List

Add the decoder sources to `CHIP_RTL_IMPL_FILES` in `rtl_setup.tcl`:

```tcl
"${DV_ROOT}/../ldpc_integration/gallager-b/hw/hdl/utils_pkg.vhd" \
"${DV_ROOT}/../ldpc_integration/gallager-b/hw/hdl/config_pkg.vhd" \
"${DV_ROOT}/../ldpc_integration/gallager-b/hw/hdl/pipelineRegister.vhd" \
"${DV_ROOT}/../ldpc_integration/gallager-b/hw/hdl/variableNodeUnit.vhd" \
"${DV_ROOT}/../ldpc_integration/gallager-b/hw/hdl/checkNodeUnit.vhd" \
"${DV_ROOT}/../ldpc_integration/gallager-b/hw/hdl/controlFlipFlop.vhd" \
"${DV_ROOT}/../ldpc_integration/gallager-b/hw/hdl/info_fifo.vhd" \
"${DV_ROOT}/../ldpc_integration/gallager-b/hw/hdl/pipelineBank_core.vhd" \
"${DV_ROOT}/../ldpc_integration/gallager-b/hw/hdl/tannerGraphProcessor.vhd" \
"${DV_ROOT}/../ldpc_integration/gallager-b/hw/hdl/GallagerB_core.vhd" \
"${DV_ROOT}/../ldpc_integration/gallager-b/hw/hdl/top.vhd" \
"${DV_ROOT}/design/chip/tile/l2/rtl/L2_ecc_decoder_wrapper.sv" \
```

The VHDL sources must remain in dependency order. In particular, `utils_pkg.vhd` and `config_pkg.vhd` must be compiled before the decoder modules.

## Pipeline Connection

Declare the decoder stall signal in `l2_pipe1.v`:

```systemverilog
wire ldpc_stall_S4;
```

Connect it to the `l2_pipe1_dpath` and `l2_pipe1_ctrl` instances:

```systemverilog
.ldpc_stall_S4 (ldpc_stall_S4),
```

## Control Logic

Add the following input to `l2_pipe1_ctrl.v`:

```systemverilog
input wire ldpc_stall_S4;
```

Add `ldpc_stall_S4` to every expression that generates an S4 stall:

```systemverilog
`ifndef NO_RTL_CSM

always @* begin
    stall_smc_buf_S4 = valid_S4 && (
           global_stall_S4
        || (msg_send_valid_S4 && !msg_send_ready_S4)
        || broadcast_stall_S4
        || stall_inv_counter_S4
        || ldpc_stall_S4
    );
end

always @* begin
    stall_S4 = valid_S4 && (
           global_stall_S4
        || msg_stall_S4
        || dir_data_stall_S4
        || (msg_send_valid_S4 && !msg_send_ready_S4)
        || stall_inv_counter_S4
        || broadcast_stall_S4
        || smc_stall_S4
        || ldpc_stall_S4
    );
end

`else

always @* begin
    stall_S4 = valid_S4 && (
           global_stall_S4
        || msg_stall_S4
        || dir_data_stall_S4
        || (msg_send_valid_S4 && !msg_send_ready_S4)
        || stall_inv_counter_S4
        || ldpc_stall_S4
    );
end

`endif
```

## Datapath Integration

Add the following output to `l2_pipe1_dpath.v`:

```systemverilog
output wire ldpc_stall_S4;
```

Replace the original SECDED decoding section with a conditional implementation:

```systemverilog
`ifdef USE_LDPC_ECC

wire         ldpc_input_ready_S4;
wire         ldpc_output_valid_S4;
wire [127:0] ldpc_output_data_S4;

L2_ecc_decoder_wrapper ldpc_decoder (
    .clk        (clk),
    .rst_ni     (rst_n),
    .valid_i    (valid_S4),
    .ready_o    (ldpc_input_ready_S4),
    .codeword_i (data_data_trans_S4),
    .valid_o    (ldpc_output_valid_S4),
    .ready_i    (valid_S4 && !stall_S4),
    .data_o     (ldpc_output_data_S4)
);

assign ldpc_stall_S4    = valid_S4 && !ldpc_output_valid_S4;
assign data_data_ecc_S4 = ldpc_output_data_S4;

always @* begin
    corr_error_S4   = 1'b0;
    uncorr_error_S4 = 1'b0;
end

`else

assign ldpc_stall_S4 = 1'b0;

l2_data_ecc data_ecc1 (
    .din          (data_data_trans_S4[63:0]),
    .parity       (data_data_trans_S4[71:64]),
    .dout         (data_data_ecc_S4[63:0]),
    .corr_error   (corr_error1_S4),
    .uncorr_error (uncorr_error1_S4)
);

l2_data_ecc data_ecc2 (
    .din          (data_data_trans_S4[135:72]),
    .parity       (data_data_trans_S4[143:136]),
    .dout         (data_data_ecc_S4[127:64]),
    .corr_error   (corr_error2_S4),
    .uncorr_error (uncorr_error2_S4)
);

always @* begin
    corr_error_S4   = corr_error1_S4 | corr_error2_S4;
    uncorr_error_S4 = uncorr_error1_S4 | uncorr_error2_S4;
end

`endif
```

The wrapper prevents the transaction held in S4 from being submitted repeatedly while `valid_S4` remains asserted.

When the decoded result is not yet available, `ldpc_stall_S4` freezes S4. Once `valid_o` is asserted and no other stall condition remains, the decoded data is accepted and the transaction continues through the pipeline.

The current LDPC interface does not provide corrected or uncorrectable error indicators. Consequently, `corr_error_S4` and `uncorr_error_S4` are set to zero in the LDPC configuration.