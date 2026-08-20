module L2_ecc_encoder_wrapper (
    input  logic [`L2_DATA_DATA_WIDTH-1:0]  data_i,
    output logic [`L2_DATA_ARRAY_WIDTH-1:0] codeword_o
);

`ifdef USE_LDPC_ECC

    // LDPC encoding
    ldpc_encoder #(
        .K           (`L2_DATA_DATA_WIDTH),
        .PARITY_BITS (`L2_DATA_ARRAY_WIDTH - `L2_DATA_DATA_WIDTH),
        .N           (`L2_DATA_ARRAY_WIDTH)
    ) ldpc_encoder_inst (
        .message_i  (data_i),
        .codeword_o (codeword_o)
    );

`else

    // Original SECDED encoding
    logic [`L2_DATA_ECC_PARITY_WIDTH-1:0] parity1;
    logic [`L2_DATA_ECC_PARITY_WIDTH-1:0] parity2;

    l2_data_pgen data_pgen1 (
        .din    (data_i[`L2_DATA_ECC_DATA_WIDTH-1:0]),
        .parity (parity1)
    );

    l2_data_pgen data_pgen2 (
        .din    (data_i[`L2_DATA_DATA_WIDTH-1:`L2_DATA_ECC_DATA_WIDTH]),
        .parity (parity2)
    );

    always_comb begin
        codeword_o = {parity2, data_i[`L2_DATA_DATA_WIDTH-1:`L2_DATA_ECC_DATA_WIDTH],
                      parity1, data_i[`L2_DATA_ECC_DATA_WIDTH-1:0]};
    end

`endif

endmodule