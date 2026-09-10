`timescale 1ns/1ps

module tb_ldpc_ecc_chain;

    localparam int DATA_WIDTH      = 128;
    localparam int PARITY_WIDTH    = 16;
    localparam int CODEWORD_WIDTH  = 144;
    localparam int CLOCK_PERIOD_NS = 10;
    localparam int TIMEOUT_CYCLES  = 1000;

    logic clock;
    logic async_nrst;
    logic input_valid;
    logic input_ready;
    logic output_valid;
    logic output_ready;

    logic [DATA_WIDTH-1:0]     original_data;
    logic [CODEWORD_WIDTH-1:0] encoder_codeword;
    logic [CODEWORD_WIDTH-1:0] decoder_codeword;
    logic [CODEWORD_WIDTH-1:0] error_mask;
    logic [CODEWORD_WIDTH-1:0] corrupted_codeword;
    logic [DATA_WIDTH-1:0]     decoded_data;

    string vectors_path;
    string results_path;
    string header;

    integer vector_file;
    integer result_file;
    integer scan_count;
    integer test_id;
    integer error_weight;
    integer cycle_count;
    integer start_cycle;
    integer end_cycle;
    integer decode_cycles;
    integer timeout_count;
    integer total_tests;
    integer recovered_tests;
    integer failed_tests;
    integer recovered;

    // Clock generation

    initial begin
        clock = 1'b0;
        forever #(CLOCK_PERIOD_NS / 2) clock = ~clock;
    end

    // Cycle counter

    always_ff @(posedge clock or negedge async_nrst) begin
        if (!async_nrst)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end

    // Encoder output: 
    // 
    // encoder_codeword[143:16] = message
    // encoder_codeword[15:0]   = parity

    ldpc_encoder #(
        .K           (DATA_WIDTH),
        .PARITY_BITS (PARITY_WIDTH),
        .N           (CODEWORD_WIDTH)
    ) u_ldpc_encoder (
        .message_i  (original_data),
        .codeword_o (encoder_codeword)
    );

    // Gallager-B expects:

    // decoder_codeword[143:128] = parity
    // decoder_codeword[127:0]   = message

    assign decoder_codeword = {
        encoder_codeword[15:0],
        encoder_codeword[143:16]
    };

    // Error injection

    assign corrupted_codeword =
        decoder_codeword ^ error_mask;

    // Mixed-language instance of the VHDL entity "top"

    top u_ldpc_decoder (
        .I_clock        (clock),
        .I_async_nrst   (async_nrst),
        .I_input_valid  (input_valid),
        .I_output_ready (output_ready),
        .I_channelBits  (corrupted_codeword),

        .O_decodedBits  (decoded_data),
        .O_output_valid (output_valid),
        .O_input_ready  (input_ready)
    );

    // Send one codeword and wait for the decoded output

    task automatic run_decoder_transaction;
        begin
            //Present the input before a rising edge

            @(negedge clock);
            input_valid = 1'b1;

            //Wait for the rising edge where the input handshake occurs

            timeout_count = 0;

            while (1) begin
                @(posedge clock);

                if (input_valid && input_ready) begin
                    start_cycle = cycle_count;
                    break;
                end

                timeout_count = timeout_count + 1;

                if (timeout_count >= TIMEOUT_CYCLES) begin
                    $fatal(1, "Input handshake timeout on test %0d", test_id);
                end
            end

            // Deassert input_valid after the accepted transaction

            @(negedge clock);
            input_valid = 1'b0;

            // Wait for the rising edge where the output handshake occurs

            timeout_count = 0;

            while (1) begin
                @(posedge clock);

                if (output_valid && output_ready) begin
                    end_cycle = cycle_count;
                    decode_cycles = end_cycle - start_cycle;
                    recovered = (decoded_data === original_data);
                    break;
                end

                timeout_count = timeout_count + 1;

                if (timeout_count >= TIMEOUT_CYCLES) begin
                    $fatal(1, "Output handshake timeout on test %0d", test_id);
                end
            end
        end
    endtask

    // Main test process

    initial begin
        async_nrst      = 1'b0;
        input_valid     = 1'b0;
        output_ready    = 1'b1;
        original_data   = '0;
        error_mask      = '0;

        total_tests     = 0;
        recovered_tests = 0;
        failed_tests    = 0;

        // Input and output files

        if (!$value$plusargs("VECTORS=%s", vectors_path)) begin
            vectors_path = "ecc_comparison_vectors.csv";
        end

        if (!$value$plusargs("RESULTS=%s", results_path)) begin
            results_path = "results/ldpc_results.csv";
        end

        // Reset the decoder

        repeat (4) @(posedge clock);

        @(negedge clock);
        async_nrst = 1'b1;

        repeat (2) @(posedge clock);

        // Open the input vector file

        vector_file = $fopen(vectors_path, "r");

        if (vector_file == 0) begin
            $fatal(1, "Unable to open vectors file: %s", vectors_path);
        end

        // Open the output result file

        result_file = $fopen(results_path, "w");

        if (result_file == 0) begin
            $fatal( 1, "Unable to open results file: %s", results_path);
        end

        // Skip the input CSV header

        scan_count = $fgets(header, vector_file);

        // Write the output CSV header

        $fdisplay(result_file, "test_id,error_weight,recovered,decode_cycles");


        // Read and execute every test
        // Input CSV format: test_id,error_weight,original_data,error_mask

        while (!$feof(vector_file)) begin
            scan_count = $fscanf(
                vector_file,
                "%d,%d,%h,%h\n",
                test_id,
                error_weight,
                original_data,
                error_mask
            );

            if (scan_count == 4) begin
                run_decoder_transaction();

                total_tests = total_tests + 1;

                if (recovered)
                    recovered_tests = recovered_tests + 1;
                else
                    failed_tests = failed_tests + 1;

                $fdisplay(
                    result_file,
                    "%0d,%0d,%0d,%0d",
                    test_id,
                    error_weight,
                    recovered,
                    decode_cycles
                );
            end
        end

        $fclose(vector_file);
        $fclose(result_file);

        $display("LDPC comparison completed");
        $display("  Total tests : %0d", total_tests);
        $display("  Recovered   : %0d", recovered_tests);
        $display("  Failed      : %0d", failed_tests);
        $display("  Results     : %s", results_path);

        if (total_tests == 0)
            $fatal(1, "No valid test vectors were read");

        $finish;
    end

endmodule