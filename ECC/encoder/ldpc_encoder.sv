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
    // Generator matrix: G = [I_K | P]
    // PARITY_MATRIX contains only P and is generated automatically by: generate_encoder_matrix_pkg.py
    // For the (144,128) code: P = 128 x 16
    import ldpc_encoder_matrix_pkg::*;

    // Internal signals
    logic [PARITY_BITS-1:0] parity;

    // Combinational parity generation
    // For each parity bit, compute the XOR reduction of all message bits connected to that parity bit by PARITY_MATRIX
    // Since PARITY_MATRIX is constant at synthesis time, the synthesis tool optimize this logic into fixed XOR
    always_comb begin

        parity = '0;

        for (int col = 0; col < PARITY_BITS; col++) begin

            parity[col] = 1'b0;

            for (int row = 0; row < K; row++) begin
                
                // message_i is MSB-first, so reverse the index (K-1-row) to match the row ordering of G
                parity[col] ^= message_i[K-1-row] & PARITY_MATRIX[row][col];

            end

        end

    end

    // Systematic codeword
    // G = [ I_K | P ]
    // The information bits are preserved and the calculated parity bits complete the codeword
    assign codeword_o = {message_i, parity};

endmodule