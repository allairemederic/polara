module L2_ecc_decoder_wrapper #(
    parameter integer DPATH_INFO_WIDTH = 1,
    parameter integer CTRL_INFO_WIDTH = 1,
    parameter integer HAZARD_KEY_WIDTH = 1,
    parameter integer FIFO_DEPTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire [143:0] codeword_i,
    input wire needs_decode_i,
    input wire [DPATH_INFO_WIDTH-1:0] dpath_info_i,
    input wire [CTRL_INFO_WIDTH-1:0] ctrl_info_i,
    input wire valid_i,
    output wire ready_o,
    output wire [127:0] data_o,
    output wire [DPATH_INFO_WIDTH-1:0] dpath_info_o,
    output wire [CTRL_INFO_WIDTH-1:0] ctrl_info_o,
    output wire valid_o,
    input wire ready_i,

    // Track addresses until their S4 processing is complete.
    input wire [HAZARD_KEY_WIDTH-1:0] hazard_key_i,
    input wire [HAZARD_KEY_WIDTH-1:0] hazard_query_i,
    output reg hazard_match_o,
    output wire [$clog2(FIFO_DEPTH + 1)-1:0] pending_count_o
);
    localparam integer PTR_WIDTH = (FIFO_DEPTH > 1) ? $clog2(FIFO_DEPTH) : 1;
    localparam integer COUNT_WIDTH = $clog2(FIFO_DEPTH + 1);
    localparam integer ENTRY_WIDTH = 1 + DPATH_INFO_WIDTH + CTRL_INFO_WIDTH;

    reg [ENTRY_WIDTH-1:0] info_mem [0:FIFO_DEPTH-1];
    reg [HAZARD_KEY_WIDTH-1:0] hazard_mem [0:FIFO_DEPTH-1];
    reg [FIFO_DEPTH-1:0] occupied_f;
    reg [PTR_WIDTH-1:0] write_ptr_f;
    reg [PTR_WIDTH-1:0] read_ptr_f;
    
    (* mark_debug = "true" *) reg [COUNT_WIDTH-1:0] count_f;

    wire [ENTRY_WIDTH-1:0] head_info;
    (* mark_debug = "true" *) wire head_needs_decode;

    (* mark_debug = "true" *) wire core_input_valid;
    (* mark_debug = "true" *) wire core_input_ready;
    (* mark_debug = "true" *) wire core_output_valid;
    (* mark_debug = "true" *) wire core_output_ready;

    wire [127:0] core_output_data;
    wire info_available, info_space;
    
    (* mark_debug = "true" *) wire input_fire;
    (* mark_debug = "true" *) wire output_fire;

    assign pending_count_o = count_f;
    assign info_available = (count_f != 0);
    assign head_info = info_available ? info_mem[read_ptr_f] : {ENTRY_WIDTH{1'b0}};
    assign {head_needs_decode, dpath_info_o, ctrl_info_o} = head_info;

    // Present the oldest transaction only.
    assign valid_o = rst_n && info_available &&
        (!head_needs_decode || core_output_valid);
    // Ignore this value for transactions that do not need decoding.
    assign data_o = head_needs_decode ? core_output_data : 128'b0;
    assign output_fire = valid_o && ready_i;

    // The core holds its result when S4 cannot finish.
    assign core_output_ready = rst_n && info_available &&
        head_needs_decode && ready_i;
    assign info_space = (count_f < FIFO_DEPTH) || output_fire;
    assign ready_o = rst_n && info_space &&
        (!needs_decode_i || core_input_ready);
    assign core_input_valid = rst_n && valid_i && needs_decode_i && info_space;
    assign input_fire = valid_i && ready_o;

    integer slot;
    always @ * begin
        hazard_match_o = 1'b0;
        for (slot = 0; slot < FIFO_DEPTH; slot = slot + 1)
            if (rst_n && occupied_f[slot] &&
                (hazard_mem[slot] == hazard_query_i))
                hazard_match_o = 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr_f <= 0;
            read_ptr_f <= 0;
            count_f <= 0;
            occupied_f <= 0;
        end else begin
            // Clear first, then set. If a full FIFO reuses the same slot,
            // the new transaction keeps the slot occupied.
            if (output_fire) begin
                occupied_f[read_ptr_f] <= 1'b0;
                if (read_ptr_f == FIFO_DEPTH - 1)
                    read_ptr_f <= 0;
                else
                    read_ptr_f <= read_ptr_f + 1'b1;
            end
            if (input_fire) begin
                info_mem[write_ptr_f] <= {needs_decode_i, dpath_info_i, ctrl_info_i};
                hazard_mem[write_ptr_f] <= hazard_key_i;
                occupied_f[write_ptr_f] <= 1'b1;
                if (write_ptr_f == FIFO_DEPTH - 1)
                    write_ptr_f <= 0;
                else
                    write_ptr_f <= write_ptr_f + 1'b1;
            end
            case ({input_fire, output_fire})
                2'b10: count_f <= count_f + 1'b1;
                2'b01: count_f <= count_f - 1'b1;
                default: count_f <= count_f;
            endcase
        end
    end

    // Reset is active-high in the supplied VHDL configuration.
    top ldpc_core (
        .I_clock (clk),
        .I_async_nrst (~rst_n),
        .I_channelBits (codeword_i),
        .I_input_valid (core_input_valid),
        .O_input_ready (core_input_ready),
        .O_decodedBits (core_output_data),
        .O_output_valid (core_output_valid),
        .I_output_ready (core_output_ready)
    );
endmodule
