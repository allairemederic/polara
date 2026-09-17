# NoC Delay Integration

`L2_delay_buffer` is inserted on both NoC interfaces of `l2_pipe1`:

- **NoC1 → L2:** 1-cycle delay before `l2_pipe1_buf_in`
- **L2 → NoC2:** 3-cycle delay after `l2_pipe1_buf_out`

Together, these buffers add four cycles to the request-response path while preserving ready/valid flow control and backpressure.

`L2_delay_buffer.sv` must be added to `CHIP_RTL_IMPL_FILES` in `rtl_setup.tcl`..

## Intermediate signals

Add the following signals to `l2_pipe1.v`:

```systemverilog
// Delayed NoC1 -> L2 request path
wire                       noc_in_delay_valid;
wire                       noc_in_delay_ready;
wire [`NOC_DATA_WIDTH-1:0] noc_in_delay_data;

// Delayed L2 -> NoC2 response path
wire                       noc_out_delay_valid;
wire                       noc_out_delay_ready;
wire [`NOC_DATA_WIDTH-1:0] noc_out_delay_data;
```

## Input delay

Between the NoC1 interface and `l2_pipe1_buf_in`.

```systemverilog
L2_delay_buffer #(
    .DATA_WIDTH (`NOC_DATA_WIDTH),
    .DELAY      (1)
) i_l2_input_delay_buffer (
    .clk_i   (clk),
    .rst_ni  (rst_n),

    .data_i  (noc_data_in),
    .valid_i (noc_valid_in),
    .ready_o (noc_ready_in),

    .data_o  (noc_in_delay_data),
    .valid_o (noc_in_delay_valid),
    .ready_i (noc_in_delay_ready)
);
```

Connect the delayed signals to `l2_pipe1_buf_in`:

```systemverilog
l2_pipe1_buf_in buf_in (
    .clk                    (clk),
    .rst_n                  (rst_n),

    .valid_in               (noc_in_delay_valid),
    .data_in                (noc_in_delay_data),
    .ready_in               (noc_in_delay_ready),

    .msg_header_valid_out   (msg_header_valid),
    .msg_header_out         (msg_header),
    .msg_header_ready_out   (msg_header_ready),

    .msg_data_valid_out     (msg_data_valid),
    .msg_data_out           (msg_data),
    .msg_data_ready_out     (msg_data_ready)
);
```

## Output delay

Between `l2_pipe1_buf_out` and the NoC2 interface.

```systemverilog
l2_pipe1_buf_out buf_out (
    .clk        (clk),
    .rst_n      (rst_n),

    .mode_in    (msg_send_mode),
    .valid_in   (msg_send_valid),
    .data_in    ({msg_send_data, msg_send_header}),
    .ready_in   (msg_send_ready),

    .valid_out  (noc_out_delay_valid),
    .data_out   (noc_out_delay_data),
    .ready_out  (noc_out_delay_ready)
);
```

Connect the delayed output to NoC2:

```systemverilog
L2_delay_buffer #(
    .DATA_WIDTH (`NOC_DATA_WIDTH),
    .DELAY      (3)
) i_l2_output_delay_buffer (
    .clk_i   (clk),
    .rst_ni  (rst_n),

    .data_i  (noc_out_delay_data),
    .valid_i (noc_out_delay_valid),
    .ready_o (noc_out_delay_ready),

    .data_o  (noc_data_out),
    .valid_o (noc_valid_out),
    .ready_i (noc_ready_out)
);
```