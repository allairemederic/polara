module tb_L2_ecc_encoder_wrapper;

    logic [`L2_DATA_DATA_WIDTH-1:0]  data_i;
    logic [`L2_DATA_ARRAY_WIDTH-1:0] codeword_o;
    logic [`L2_DATA_ARRAY_WIDTH-1:0] expected;

    int tests  = 0;
    int errors = 0;

    L2_ecc_encoder_wrapper dut (
        .data_i     (data_i),
        .codeword_o (codeword_o)
    );

`ifdef USE_LDPC_ECC

    // Reference LDPC encoder
    ldpc_encoder #(
        .K           (`L2_DATA_DATA_WIDTH),
        .PARITY_BITS (`L2_DATA_ARRAY_WIDTH - `L2_DATA_DATA_WIDTH),
        .N           (`L2_DATA_ARRAY_WIDTH)
    ) ref_encoder (
        .message_i  (data_i),
        .codeword_o (expected)
    );

`else

    logic [`L2_DATA_ECC_PARITY_WIDTH-1:0] parity1_ref;
    logic [`L2_DATA_ECC_PARITY_WIDTH-1:0] parity2_ref;

    l2_data_pgen ref_pgen1 (
        .din    (data_i[`L2_DATA_ECC_DATA_WIDTH-1:0]),
        .parity (parity1_ref)
    );

    l2_data_pgen ref_pgen2 (
        .din    (data_i[`L2_DATA_DATA_WIDTH-1:
                        `L2_DATA_ECC_DATA_WIDTH]),
        .parity (parity2_ref)
    );

    always_comb begin
        expected = {
            parity2_ref,
            data_i[`L2_DATA_DATA_WIDTH-1:
                   `L2_DATA_ECC_DATA_WIDTH],
            parity1_ref,
            data_i[`L2_DATA_ECC_DATA_WIDTH-1:0]
        };
    end

`endif

    task automatic check(input logic [`L2_DATA_DATA_WIDTH-1:0] data);
        begin
            data_i = data;
            #1;

            tests++;

            if (codeword_o !== expected) begin
                errors++;
                $display("FAIL");
                $display("  data     = %h", data_i);
                $display("  expected = %h", expected);
                $display("  got      = %h", codeword_o);
            end
        end
    endtask

    initial begin

`ifdef USE_LDPC_ECC
        $display("Testing L2 ECC wrapper: LDPC mode");
`else
        $display("Testing L2 ECC wrapper: SECDED mode");
`endif

        // Deterministic cases
        check('0);
        check('1);

        check({{(`L2_DATA_DATA_WIDTH-1){1'b0}}, 1'b1});
        check({1'b1, {(`L2_DATA_DATA_WIDTH-1){1'b0}}});

        // Random cases
        repeat (1000) begin
            check({
                $urandom(),
                $urandom(),
                $urandom(),
                $urandom()
            });
        end

        $display("--------------------------------");
        $display("Tests  : %0d", tests);
        $display("Passed : %0d", tests - errors);
        $display("Failed : %0d", errors);
        $display("--------------------------------");

        if (errors == 0)
            $display("PASS");
        else
            $fatal(1, "Wrapper verification failed");

        $finish;
    end

endmodule