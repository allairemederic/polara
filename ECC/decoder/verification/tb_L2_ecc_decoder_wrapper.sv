`timescale 1ns/1ps

module tb_L2_ecc_decoder_wrapper;

    localparam int MAX_CYCLES = 200;

    localparam logic [127:0] DATA1 =
        128'h00112233445566778899AABBCCDDEEFF;

    localparam logic [127:0] DATA2 =
        128'hFEDCBA98765432100123456789ABCDEF;

    logic clk   = 1'b0;
    logic rst_n = 1'b0;

    logic         valid_S4 = 1'b0;
    logic [143:0] data_data_trans_S4 = '0;
    logic         other_stall_S4 = 1'b0;

    /*
     * Encoder signals.
     */
    logic [127:0] encoder_data = '0;
    wire  [143:0] encoder_codeword;

    /*
     * Decoder signals.
     */
    wire         ldpc_input_ready_S4;
    wire         ldpc_output_valid_S4;
    wire [127:0] data_data_ecc_S4;

    wire ldpc_stall_S4;
    wire stall_S4;
    wire ldpc_output_ready_S4;

    int input_count  = 0;
    int output_count = 0;
    int debug_cycle  = 0;

    always #5 clk = ~clk;

    /*
     * Real LDPC encoder.
     */
    L2_ecc_encoder_wrapper encoder (
        .data_i     (encoder_data),
        .codeword_o (encoder_codeword)
    );

    /*
     * Same control relationships used in pipe1.
     */
    assign ldpc_stall_S4 =
        valid_S4 && !ldpc_output_valid_S4;

    assign stall_S4 =
        valid_S4 &&
        (other_stall_S4 || ldpc_stall_S4);

    assign ldpc_output_ready_S4 =
        valid_S4 && !stall_S4;

    /*
     * Real LDPC decoder wrapper.
     */
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

    /*
     * Count transfers at the real VHDL decoder interface.
     */
    always @(posedge clk)
    begin
        if (rst_n)
        begin
            if (dut.input_fire)
                input_count <= input_count + 1;

            if (dut.output_fire)
                output_count <= output_count + 1;
        end
    end

    /*
     * Print the wrapper handshake during the first cycles.
     */
    always @(posedge clk)
    begin
        if (!rst_n)
        begin
            debug_cycle <= 0;
        end
        else
        begin
            debug_cycle <= debug_cycle + 1;

            if (debug_cycle < 30 ||
                dut.input_fire ||
                dut.core_output_valid ||
                dut.output_fire)
            begin
                $display(
                    "cycle=%0d rst_n=%b ldpc_reset=%b valid_S4=%b core_in_valid=%b core_in_ready=%b input_fire=%b inflight=%b core_out_valid=%b core_out_ready=%b output_fire=%b",
                    debug_cycle,
                    rst_n,
                    ~rst_n,
                    valid_S4,
                    dut.core_input_valid,
                    dut.core_input_ready,
                    dut.input_fire,
                    dut.request_inflight_f,
                    dut.core_output_valid,
                    dut.core_output_ready,
                    dut.output_fire
                );
            end
        end
    end

    task automatic wait_for_result(
        input logic [127:0] expected,
        input int           expected_input_count
    );
        int cycles;

        cycles = 0;

        while (!ldpc_output_valid_S4 &&
               cycles < MAX_CYCLES)
        begin
            @(negedge clk);
            cycles++;
        end

        if (!ldpc_output_valid_S4)
        begin
            $display(
                "TIMEOUT: input_ready=%b input_valid=%b",
                dut.core_input_ready,
                dut.core_input_valid
            );

            $display(
                "TIMEOUT: output_valid=%b output_ready=%b",
                dut.core_output_valid,
                dut.core_output_ready
            );

            $display(
                "TIMEOUT: request_inflight=%b stall=%b",
                dut.request_inflight_f,
                ldpc_stall_S4
            );

            $fatal(
                1,
                "Timeout waiting for LDPC result"
            );
        end

        if (input_count != expected_input_count)
        begin
            $fatal(
                1,
                "Input transfers: got %0d, expected %0d",
                input_count,
                expected_input_count
            );
        end

        if (data_data_ecc_S4 !== expected)
        begin
            $fatal(
                1,
                "Decoded data: got %032h, expected %032h",
                data_data_ecc_S4,
                expected
            );
        end
    endtask

    initial
    begin
        /*
         * Reset the wrapper and the VHDL decoder.
         */
        repeat (5) @(negedge clk);
        rst_n = 1'b1;

        /*
         * Encode the first nonzero data word.
         */
        encoder_data = DATA1;
        #1;

        $display(
            "ENCODE 1: data=%032h codeword=%036h",
            encoder_data,
            encoder_codeword
        );

        /*
         * First transaction enters S4.
         */
        @(negedge clk);
        valid_S4 = 1'b1;
        data_data_trans_S4 = encoder_codeword;

        wait_for_result(
            DATA1,
            1
        );

        /*
         * Block the pipe1 output after decoding. The decoder output
         * must remain valid and stable.
         */
        other_stall_S4 = 1'b1;

        repeat (4)
        begin
            @(negedge clk);

            if (!stall_S4 ||
                ldpc_output_ready_S4)
            begin
                $fatal(
                    1,
                    "S4 advanced while downstream was blocked"
                );
            end

            if (!ldpc_output_valid_S4 ||
                data_data_ecc_S4 !== DATA1)
            begin
                $fatal(
                    1,
                    "Decoder result changed under backpressure"
                );
            end

            if (input_count != 1)
            begin
                $fatal(
                    1,
                    "First transaction was submitted more than once"
                );
            end
        end

        /*
         * Release downstream. The first transaction leaves S4.
         */
        other_stall_S4 = 1'b0;
        #1;

        if (stall_S4 ||
            !ldpc_output_ready_S4)
        begin
            $fatal(
                1,
                "S4 did not become ready"
            );
        end

        @(posedge clk);
        #1;

        if (output_count != 1)
        begin
            $fatal(
                1,
                "First result was not consumed"
            );
        end

        /*
         * Encode a second nonzero data word.
         */
        @(negedge clk);
        encoder_data = DATA2;
        #1;

        $display(
            "ENCODE 2: data=%032h codeword=%036h",
            encoder_data,
            encoder_codeword
        );

        /*
         * Replace S4 without lowering valid_S4.
         */
        data_data_trans_S4 = encoder_codeword;

        wait_for_result(
            DATA2,
            2
        );

        if (stall_S4 ||
            !ldpc_output_ready_S4)
        begin
            $fatal(
                1,
                "Second transaction cannot leave S4"
            );
        end

        @(posedge clk);
        #1;

        if (output_count != 2)
        begin
            $fatal(
                1,
                "Second result was not consumed"
            );
        end

        @(negedge clk);
        valid_S4 = 1'b0;

        if (input_count != 2 ||
            output_count != 2)
        begin
            $fatal(
                1,
                "Counts: input=%0d output=%0d",
                input_count,
                output_count
            );
        end

        $display(
            "PASS: LDPC encoder-decoder round trip, S4 control, backpressure and consecutive transactions"
        );

        $finish;
    end

    /*
     * Global timeout: 10 000 cycles at 100 MHz.
     */
    initial
    begin
        #100000;
        $fatal(
            1,
            "Global testbench timeout"
        );
    end
endmodule