module top (
    input  wire         I_clock,
    input  wire         I_async_nrst,
    input  wire         I_input_valid,
    input  wire         I_output_ready,
    input  wire [143:0] I_channelBits,

    output reg  [127:0] O_decodedBits,
    output reg          O_output_valid,
    output wire         O_input_ready
);

    reg [2:0] cycles_left;

    // Like the real top: block the pipeline when its output is stalled
    assign O_input_ready = !(O_output_valid && !I_output_ready);

    always @(posedge I_clock or negedge I_async_nrst) begin
        if (!I_async_nrst) begin
            cycles_left   <= 0;
            O_output_valid <= 0;
            O_decodedBits <= 0;
        end
        else if (O_input_ready) begin
            if (I_input_valid) begin

                // Every accepted input restarts the mock calculation
                // Repeated submissions will therefore be visible
                O_decodedBits  <= I_channelBits[127:0];
                O_output_valid <= 0;
                cycles_left    <= 3;
            end
            else if (cycles_left != 0) begin
                cycles_left <= cycles_left - 1'b1;

                if (cycles_left == 1)
                    O_output_valid <= 1;
            end
            else if (O_output_valid && I_output_ready) begin
                O_output_valid <= 0;
            end
        end
    end

endmodule