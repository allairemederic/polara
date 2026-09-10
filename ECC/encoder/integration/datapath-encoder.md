# ECC Encoder Integration

The `L2_ecc_encoder_wrapper` replaces the direct SECDED parity-generation logic in both L2 datapaths.

The wrapper receives a 128-bit data word and generates the corresponding 144-bit LDPC or SECDED codeword, depending on the selected configuration.

The `L2_ecc_encoder_wrapper.sv` and `ldpc_encoder.sv` modules must be added to the RTL source list defined by `CHIP_RTL_IMPL_FILES` in `rtl_setup.tcl`.

## `l2_pipe1_dpath.v`

The wrapper encodes `data_data_merge_S2` before it is written to the L2 data array:

```systemverilog
wire [`L2_DATA_ARRAY_WIDTH-1:0] ecc_codeword_S2;

L2_ecc_encoder_wrapper ecc_encoder (
    .data_i     (data_data_merge_S2),
    .codeword_o (ecc_codeword_S2)
);

always @ *
begin
    if (special_addr_type_S2)
    begin
        data_data_in_S2 = {
            msg_data_S2[`L2_DATA_ECC_PARITY_WIDTH-1:0],
            msg_data_S2,
            msg_data_S2[`L2_DATA_ECC_PARITY_WIDTH-1:0],
            msg_data_S2
        };
    end
    else
    begin
        data_data_in_S2 = ecc_codeword_S2;
    end
end
```

## `l2_pipe2_dpath.v`

The wrapper encodes `msg_data_S2` before it is written to the L2 data array:

```systemverilog
wire [`L2_DATA_ARRAY_WIDTH-1:0] ecc_codeword_S2;

L2_ecc_encoder_wrapper ecc_encoder (
    .data_i     (msg_data_S2),
    .codeword_o (ecc_codeword_S2)
);

always @ *
begin
    data_data_in_S2 = ecc_codeword_S2;
end
```

The ECC implementation is selected inside `L2_ecc_encoder_wrapper`, allowing both datapaths to use the same interface without duplicating LDPC and SECDED selection logic.

## RTL Source files

In rtl_setup.tcl

```systemverilog
    "${DV_ROOT}/design/chip/tile/l2/rtl/ldpc_encoder_matrix_pkg.sv" \
    "${DV_ROOT}/design/chip/tile/l2/rtl/ldpc_encoder.sv" \
    "${DV_ROOT}/design/chip/tile/l2/rtl/L2_ecc_encoder_wrapper.sv" \
```