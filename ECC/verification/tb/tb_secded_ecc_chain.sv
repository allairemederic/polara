`timescale 1ns/1ps

module tb_secded_ecc_chain;

    localparam int DATA_WIDTH     = 128;
    localparam int CODEWORD_WIDTH = 144;

    logic [DATA_WIDTH-1:0]     original_data;
    logic [15:0]               generated_parity;
    logic [CODEWORD_WIDTH-1:0] encoded_codeword;
    logic [CODEWORD_WIDTH-1:0] error_mask;
    logic [CODEWORD_WIDTH-1:0] corrupted_codeword;

    logic [DATA_WIDTH-1:0] decoded_data;

    logic corr_error_low;
    logic corr_error_high;
    logic uncorr_error_low;
    logic uncorr_error_high;

    logic recovered;
    logic error_detected;

    string vectors_path;
    string results_path;
    string header;

    integer vector_file;
    integer result_file;
    integer scan_count;

    integer test_id;
    integer error_weight;

    integer total_tests;
    integer recovered_tests;
    integer failed_tests;

    // Generate the two 8-bit SECDED parity fields

    l2_data_pgen u_pgen_low (
        .din    (original_data[63:0]),
        .parity (generated_parity[7:0])
    );

    l2_data_pgen u_pgen_high (
        .din    (original_data[127:64]),
        .parity (generated_parity[15:8])
    );


    // L2 codeword layout: parity2 data2 parity1 data1

    assign encoded_codeword = {
        generated_parity[15:8],
        original_data[127:64],
        generated_parity[7:0],
        original_data[63:0]
    };

    // Inject errors into the SECDED codeword

    assign corrupted_codeword = encoded_codeword ^ error_mask;

    //Decode data1 and parity1

    l2_data_ecc u_ecc_low (
        .din          (corrupted_codeword[63:0]),
        .parity       (corrupted_codeword[71:64]),
        .dout         (decoded_data[63:0]),
        .corr_error   (corr_error_low),
        .uncorr_error (uncorr_error_low)
    );

    // Decode data2 and parity2

    l2_data_ecc u_ecc_high (
        .din          (corrupted_codeword[135:72]),
        .parity       (corrupted_codeword[143:136]),
        .dout         (decoded_data[127:64]),
        .corr_error   (corr_error_high),
        .uncorr_error (uncorr_error_high)
    );

    // Check whether the original 128-bit data word was recovered

    always_comb begin
        recovered = (decoded_data === original_data);

        error_detected =
            corr_error_low   ||
            corr_error_high  ||
            uncorr_error_low ||
            uncorr_error_high;
    end

    initial begin
        total_tests     = 0;
        recovered_tests = 0;
        failed_tests    = 0;

        original_data = '0;
        error_mask    = '0;

        if (!$value$plusargs("VECTORS=%s", vectors_path)) begin
            vectors_path = "ecc_comparison_vectors.csv";
        end

        if (!$value$plusargs("RESULTS=%s", results_path)) begin
            results_path = "results/secded_results.csv";
        end

        // Open the input vector file

        vector_file = $fopen(vectors_path, "r");

        if (vector_file == 0) begin
            $fatal(1, "Unable to open test-vector file: %s", vectors_path);
        end

        // Open the output result file

        result_file = $fopen(results_path, "w");

        if (result_file == 0) begin
            $fatal(1, "Unable to open result file: %s", results_path);
        end

        // Skip the input CSV header

        scan_count = $fgets(header, vector_file);

        // Create the output CSV header

        $fdisplay(
            result_file,
            "test_id,error_weight,recovered,error_detected,decode_cycles"
        );

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

                // Allow the combinational logic to settle
                #1;

                total_tests = total_tests + 1;

                if (recovered) begin
                    recovered_tests = recovered_tests + 1;
                end else begin
                    failed_tests = failed_tests + 1;
                end

                // Output CSV format:
                //
                // test_id
                // error_weight
                // recovered
                // error_detected
                // decode_cycles

                $fdisplay(
                    result_file,
                    "%0d,%0d,%0d,%0d,0",
                    test_id,
                    error_weight,
                    recovered,
                    error_detected
                );
            end
        end

        $fclose(vector_file);
        $fclose(result_file);

        $display("");
        $display("SECDED comparison completed");
        $display("---------------------------");
        $display("Total tests : %0d", total_tests);
        $display("Recovered   : %0d", recovered_tests);
        $display("Failed      : %0d", failed_tests);
        $display("Results     : %s", results_path);
        $display("");

        if (total_tests == 0) begin
            $fatal(1, "No valid test vectors were read");
        end

        $finish;
    end

endmodule