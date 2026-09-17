module ldpc_encoder_simulator #(
    parameter bit PIPELINE = 1'b0    // 0 = combinational, 1 = 1-cycle pipeline
)
(
    input  logic         clk,
    input  logic         rst_ni,

    input  logic [127:0] message_i,
    input  logic [7:0]   parity1_i,
    input  logic [7:0]   parity2_i,

    output logic [143:0] codeword_o
);

    // -------------------------------------------------------------------------
    // LDPC integration simulator
    // Reproduces the current SECDED codeword format 
    // -------------------------------------------------------------------------

    logic [143:0] codeword_comb;

    always_comb begin
        codeword_comb = { parity2_i, message_i[127:64], parity1_i, message_i[63:0] };
    end

    // -------------------------------------------------------------------------
    // Optional 1-cycle pipeline
    // -------------------------------------------------------------------------
    generate

        if (PIPELINE == 1'b0) begin : g_comb
            assign codeword_o = codeword_comb;

        end
        else begin : g_pipe

            always_ff @(posedge clk or negedge rst_ni) begin
                if (!rst_ni)
                    codeword_o <= '0;
                else
                    codeword_o <= codeword_comb;
            end

        end

    endgenerate


endmodule