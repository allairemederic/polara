`timescale 1ns/1ps

module tb_L2_ecc_decoder_wrapper;

    localparam int MAX_CYCLES = 30;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic         valid_S4 = 1'b0;
    logic [143:0] data_data_trans_S4 = '0;
    logic         other_stall_S4 = 1'b0;

    wire          ldpc_input_ready_S4;
    wire          ldpc_output_valid_S4;
    wire [127:0]  data_data_ecc_S4;

    wire ldpc_stall_S4;
    wire stall_S4;
    wire ldpc_output_ready_S4;

    int input_count = 0;
    int output_count = 0;

    always #5 clk = ~clk;

    // Same control relationship used in pipe1.
    assign ldpc_stall_S4 =
        valid_S4 && !ldpc_output_valid_S4;

    assign stall_S4 =
        valid_S4 && (other_stall_S4 || ldpc_stall_S4);

    assign ldpc_output_ready_S4 =
        valid_S4 && !stall_S4;

    L2_ecc_decoder_wrapper dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .codeword_i (data_data_trans_S4),
        .valid_i    (valid_S4),
        .ready_o    (ldpc_input_ready_S4),
        .data_o     (data_data_ecc_S4),
        .valid_o    (ldpc_output_valid_S4),
        .ready_i    (ldpc_output_ready_S4)
    );

    // Count transfers at the VHDL core interface emulated by top_mock.
    always @(posedge clk) begin
        if (rst_n) begin
            if (dut.input_fire)
                input_count <= input_count + 1;

            if (dut.output_fire)
                output_count <= output_count + 1;
        end
    end

    task automatic wait_for_result(
        input logic [127:0] expected,
        input int           expected_input_count
    );
        int cycles;

        cycles = 0;

        while (!ldpc_output_valid_S4 && cycles < MAX_CYCLES) begin
            @(negedge clk);
            cycles++;
        end

        if (!ldpc_output_valid_S4)
            $fatal(1, "Timeout waiting for LDPC result");

        if (input_count != expected_input_count)
            $fatal(1, "Input transfers: got %0d, expected %0d",
                   input_count, expected_input_count);

        if (data_data_ecc_S4 !== expected)
            $fatal(1, "Decoded data: got %032h, expected %032h",
                   data_data_ecc_S4, expected);
    endtask

    initial begin
        repeat (5) @(negedge clk);
        rst_n = 1'b1;

        // First transaction enters S4.
        @(negedge clk);
        valid_S4 = 1'b1;
        data_data_trans_S4 =
            144'h1234_00112233445566778899AABBCCDDEEFF;

        wait_for_result(
            128'h00112233445566778899AABBCCDDEEFF,
            1
        );

        // The decoder has finished, but the pipe1 output is blocked.
        other_stall_S4 = 1'b1;

        repeat (4) begin
            @(negedge clk);

            if (!stall_S4 || ldpc_output_ready_S4)
                $fatal(1, "S4 advanced while downstream was blocked");

            if (!ldpc_output_valid_S4 ||
                data_data_ecc_S4 !==
                    128'h00112233445566778899AABBCCDDEEFF)
                $fatal(1, "Decoder result changed under backpressure");

            if (input_count != 1)
                $fatal(1, "First transaction was submitted again");
        end

        // Release downstream. The first transaction leaves S4.
        other_stall_S4 = 1'b0;
        #1;

        if (stall_S4 || !ldpc_output_ready_S4)
            $fatal(1, "S4 did not become ready");

        @(posedge clk);
        #1;

        if (output_count != 1)
            $fatal(1, "First result was not consumed");

        // Replace S4 with the next transaction without lowering valid_S4.
        @(negedge clk);
        data_data_trans_S4 =
            144'hABCD_FEDCBA98765432100123456789ABCDEF;

        wait_for_result(
            128'hFEDCBA98765432100123456789ABCDEF,
            2
        );

        if (stall_S4 || !ldpc_output_ready_S4)
            $fatal(1, "Second transaction cannot leave S4");

        @(posedge clk);
        #1;

        if (output_count != 2)
            $fatal(1, "Second result was not consumed");

        @(negedge clk);
        valid_S4 = 1'b0;

        if (input_count != 2 || output_count != 2)
            $fatal(1, "Counts: input=%0d output=%0d",
                   input_count, output_count);

        $display("PASS: S4 control, backpressure and consecutive transactions");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Global testbench timeout");
    end

endmodule