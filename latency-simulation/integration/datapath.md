# Datapath Delay Integration

The `SIMULATE_LDPC_LATENCY` configuration evaluates the future LDPC integration points while preserving the original SECDED protection.

- `ldpc_encoder_simulator` validates the encoder placement in both L2 write paths
- `L2_delay_buffer` adds four cycles to the pipe1 response path to model decoder latency

`L2_delay_buffer.sv` and `ldpc_encoder_simulator.sv` must be added to `CHIP_RTL_IMPL_FILES` in `rtl_setup.tcl`.


## Decoder Latency

In `l2_pipe1.v`, the delay buffer is inserted before `l2_pipe1_buf_out. The response payload, header, and mode are delayed together to preserve their alignment.

```systemverilog
`ifdef SIMULATE_LDPC_LATENCY

wire msg_valid_out;
wire msg_ready_out;
wire [`NOC_DATA_WIDTH*5-1:0] msg_data_out;
wire [`L2_P1_BUF_OUT_MODE_WIDTH-1:0] msg_mode_out;

L2_delay_buffer #(
    .DATA_WIDTH (`NOC_DATA_WIDTH*5),
    .DELAY      (4),
    .MODE_WIDTH (`L2_P1_BUF_OUT_MODE_WIDTH)
) i_l2_output_delay_buffer (
    .clk_i   (clk),
    .rst_ni  (rst_n),

    .mode_i  (msg_send_mode),
    .data_i  ({msg_send_data, msg_send_header}),
    .valid_i (msg_send_valid),
    .ready_o (msg_send_ready),

    .mode_o  (msg_mode_out),
    .data_o  (msg_data_out),
    .valid_o (msg_valid_out),
    .ready_i (msg_ready_out)
);

`endif
```

The delayed signals are selected at the input of `l2_pipe1_buf_out`:

```systemverilog
l2_pipe1_buf_out buf_out (
    .clk   (clk),
    .rst_n (rst_n),

`ifdef SIMULATE_LDPC_LATENCY
    .mode_in  (msg_mode_out),
    .valid_in (msg_valid_out),
    .data_in  (msg_data_out),
    .ready_in (msg_ready_out),
`else
    .mode_in  (msg_send_mode),
    .valid_in (msg_send_valid),
    .data_in  ({msg_send_data, msg_send_header}),
    .ready_in (msg_send_ready),
`endif

    .valid_out (noc_valid_out),
    .data_out  (noc_data_out),
    .ready_out (noc_ready_out)
);
```

## Encoder Latency

The encoder simulator is inserted in both write paths without replacing the existing SECDED parity generators.

### `l2_pipe1_dpath.v`

```systemverilog
`ifdef SIMULATE_LDPC_LATENCY

wire [`L2_DATA_ARRAY_WIDTH-1:0] ldpc_sim_codeword;

ldpc_encoder_simulator #(
    .PIPELINE (1'b0)
) ldpc_encoder_sim (
    .clk        (clk),
    .rst_ni     (rst_n),

    .message_i  (data_data_merge_S2),
    .parity1_i  (data_data_parity1_S2),
    .parity2_i  (data_data_parity2_S2),

    .codeword_o (ldpc_sim_codeword)
);

`endif
```

### `l2_pipe2_dpath.v`

```systemverilog
`ifdef SIMULATE_LDPC_LATENCY

wire [`L2_DATA_ARRAY_WIDTH-1:0] ldpc_sim_codeword;

ldpc_encoder_simulator #(
    .PIPELINE (1'b0)
) ldpc_encoder_sim (
    .clk        (clk),
    .rst_ni     (rst_n),

    .message_i  (msg_data_S2),
    .parity1_i  (msg_data_parity1_S2),
    .parity2_i  (msg_data_parity2_S2),

    .codeword_o (ldpc_sim_codeword)
);

`endif
```