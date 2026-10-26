module ldpc_encoder
#(
    parameter int K             = 128,
    parameter int PARITY_BITS   = 16,
    parameter int N             = K + PARITY_BITS
)
(
    input  logic [K-1:0]     message_i,
    output logic [N-1:0]     codeword_o
);

    // Import LDPC encoder matrix
    import ldpc_encoder_matrix_pkg::*;

    // Internal signals
    logic [PARITY_BITS-1:0] parity;

    // Combinational parity generation
    // For each parity bit, compute the XOR reduction of all message bits connected to that parity bit by PARITY_MATRIX
    // Since PARITY_MATRIX is constant at synthesis time, the synthesis tool optimize this logic into fixed XOR
    always_comb begin

        parity = '0;

        for (int col = 0; col < PARITY_BITS; col++) begin

            for (int row = 0; row < K; row++) begin
                
                parity[col] ^= message_i[row] & PARITY_MATRIX[row][col];

            end

        end

    end

    // Keep the data bits unchanged
    assign codeword_o[K-1:0] = message_i;

    // Match the decoder parity-bit order.
    for (genvar j = 0; j < PARITY_BITS; j++) begin : parity_order
        assign codeword_o[K+j] = parity[PARITY_BITS-1-j];
    end

endmodule