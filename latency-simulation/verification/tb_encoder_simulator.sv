`timescale 1ns/1ps

module tb_fake_ldpc_encoder;

    //----------------------------------------------------------
    // Signals
    //----------------------------------------------------------

    logic         clk;
    logic         rst_ni;

    logic [127:0] message_i;
    logic [7:0]   parity1_i;
    logic [7:0]   parity2_i;

    logic [143:0] codeword_comb_o;
    logic [143:0] codeword_pipe_o;

    logic [143:0] expected;

    //----------------------------------------------------------
    // Clock
    //----------------------------------------------------------

    initial clk = 0;
    always #5 clk = ~clk;

    //----------------------------------------------------------
    // DUT - Combinational
    //----------------------------------------------------------

    fake_ldpc_encoder #(
        .PIPELINE(0)
    ) dut_comb (
        .clk(clk),
        .rst_ni(rst_ni),
        .message_i(message_i),
        .parity1_i(parity1_i),
        .parity2_i(parity2_i),
        .codeword_o(codeword_comb_o)
    );

    //----------------------------------------------------------
    // DUT - Pipelined
    //----------------------------------------------------------

    fake_ldpc_encoder #(
        .PIPELINE(1)
    ) dut_pipe (
        .clk(clk),
        .rst_ni(rst_ni),
        .message_i(message_i),
        .parity1_i(parity1_i),
        .parity2_i(parity2_i),
        .codeword_o(codeword_pipe_o)
    );

    //----------------------------------------------------------
    // Tests
    //----------------------------------------------------------

    initial begin

        rst_ni = 0;

        message_i = '0;
        parity1_i = '0;
        parity2_i = '0;

        repeat(2) @(posedge clk);

        rst_ni = 1;

        //------------------------------------------------------
        // Test 1
        //------------------------------------------------------

        message_i =
            128'h0123456789ABCDEF_FEDCBA9876543210;

        parity1_i = 8'hAA;
        parity2_i = 8'h55;

        expected = {
            parity2_i,
            message_i[127:64],
            parity1_i,
            message_i[63:0]
        };

        #1;

        assert(codeword_comb_o == expected)
            else $fatal("Combinational encoder failed (Test 1)");

        @(posedge clk);

        assert(codeword_pipe_o == expected)
            else $fatal("Pipelined encoder failed (Test 1)");

        //------------------------------------------------------
        // Test 2
        //------------------------------------------------------

        message_i =
            128'hFFFFFFFF00000000_123456789ABCDEF0;

        parity1_i = 8'h11;
        parity2_i = 8'h22;

        expected = {
            parity2_i,
            message_i[127:64],
            parity1_i,
            message_i[63:0]
        };

        #1;

        assert(codeword_comb_o == expected)
            else $fatal("Combinational encoder failed (Test 2)");

        @(posedge clk);

        assert(codeword_pipe_o == expected)
            else $fatal("Pipelined encoder failed (Test 2)");

        //------------------------------------------------------

        $display("");
        $display("======================================");
        $display(" All fake_ldpc_encoder tests PASSED!");
        $display("======================================");
        $display("");

        $finish;

    end

endmodule