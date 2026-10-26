module L2_ecc_decoder_wrapper (
    input  wire         clk,
    input  wire         rst_n,

    // Codeword read from the L2 cache
    input  wire [143:0] codeword_i,
    input  wire         valid_i,
    output wire         ready_o,

    // Decoded word
    output wire [127:0] data_o,
    output wire         valid_o,
    input  wire         ready_i
);

    // The POLARA reset is active-low, while the VHDL decoder reset is active-high
    wire ldpc_reset;

    // Prevents repeated submission of a stalled S4 transaction
    reg request_inflight_f;

    wire         core_input_valid;
    wire         core_input_ready;
    wire         core_output_valid;
    wire         core_output_ready;
    wire [127:0] core_output_data;

    wire input_fire;
    wire output_fire;

    assign ldpc_reset = ~rst_n;

    // Accept a request only when none is in flight
    assign core_input_valid = valid_i && !request_inflight_f;
    assign ready_o = core_input_ready && !request_inflight_f;

    // Internal handshakes
    assign input_fire  = core_input_valid && core_input_ready;
    assign output_fire = core_output_valid && core_output_ready;

    // The VHDL core holds its output stable under backpressure
    assign valid_o           = core_output_valid;
    assign data_o            = core_output_data;
    assign core_output_ready = ready_i;

    // Track one LDPC request for the current S4 transaction
    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            request_inflight_f <= 1'b0;
        end
        else
        begin
            case ({input_fire, output_fire})
                2'b10:
                    request_inflight_f <= 1'b1;

                2'b01:
                    request_inflight_f <= 1'b0;

                // 2'b00: No transfer
                // 2'b11: Input and output transferred simultaneously
                default:
                    request_inflight_f <= request_inflight_f;
            endcase
        end
    end

    // Gallager-B decoder
    top ldpc_core (
        .I_clock         (clk),

        // Input is active-high because of PKG_ASYNC_RESET_LOGIC
        .I_async_nrst    (ldpc_reset),

        .I_input_valid   (core_input_valid),
        .I_output_ready  (core_output_ready),
        .I_channelBits   (codeword_i),

        .O_decodedBits   (core_output_data),
        .O_output_valid  (core_output_valid),
        .O_input_ready   (core_input_ready)
    );

endmodule