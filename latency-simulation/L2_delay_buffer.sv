module L2_delay_buffer #(
    parameter int DATA_WIDTH = 256,
    parameter int DELAY      = 4,
    parameter int MODE_WIDTH = 3
)(
    input  logic clk_i,
    input  logic rst_ni,

    input  logic                     valid_i,
    input  logic [DATA_WIDTH-1:0]    data_i,
    input  logic [MODE_WIDTH-1:0]   mode_i,
    output logic                     ready_o,

    output logic                     valid_o,
    output logic [MODE_WIDTH-1:0]   mode_o,
    output logic [DATA_WIDTH-1:0]    data_o,
    input  logic                     ready_i
);

    logic [DELAY-1:0]        valid_pipe;
    logic [DATA_WIDTH-1:0]   data_pipe [DELAY-1:0];
    logic [DELAY-1:0]        ready_pipe;
    logic [MODE_WIDTH-1:0]   mode_pipe [DELAY-1:0];

    //----------------------------------------------------------
    // READY propagation (backward)
    //----------------------------------------------------------

    assign ready_pipe[DELAY-1] =
        ready_i || !valid_pipe[DELAY-1];

    genvar g;
    generate
        for (g = DELAY-2; g >= 0; g--) begin : READY_GEN
            assign ready_pipe[g] =
                ready_pipe[g+1] || !valid_pipe[g];
        end
    endgenerate

    assign ready_o = ready_pipe[0];

    //----------------------------------------------------------
    // PIPELINE REGISTERS
    //----------------------------------------------------------

    integer i;

    always_ff @(posedge clk_i or negedge rst_ni) begin

        if (!rst_ni) begin

            for (i = 0; i < DELAY; i++) begin
                valid_pipe[i] <= 1'b0;
                data_pipe[i]  <= '0;
                mode_pipe[i]  <= '0;
            end

        end
        else begin

            //--------------------------------------------------
            // LAST STAGE
            //--------------------------------------------------

            if (ready_pipe[DELAY-1]) begin

                if (DELAY == 1) begin
                    valid_pipe[0] <= valid_i;
                    data_pipe[0]  <= data_i;
                    mode_pipe[0]  <= mode_i;
                end
                else begin
                    valid_pipe[DELAY-1] <= valid_pipe[DELAY-2];
                    data_pipe[DELAY-1]  <= data_pipe[DELAY-2];
                    mode_pipe[DELAY-1]  <= mode_pipe[DELAY-2];
                end

            end

            //--------------------------------------------------
            // INTERMEDIATE STAGES
            //--------------------------------------------------

            for (i = DELAY-2; i > 0; i--) begin

                if (ready_pipe[i]) begin
                    valid_pipe[i] <= valid_pipe[i-1];
                    data_pipe[i]  <= data_pipe[i-1];
                    mode_pipe[i]  <= mode_pipe[i-1];
                end

            end

            //--------------------------------------------------
            // FIRST STAGE
            //--------------------------------------------------

            if (DELAY > 1) begin

                if (ready_pipe[0]) begin
                    valid_pipe[0] <= valid_i;
                    data_pipe[0]  <= data_i;
                    mode_pipe[0]  <= mode_i;
                end

            end

        end
    end

    //----------------------------------------------------------
    // OUTPUTS
    //----------------------------------------------------------

    assign valid_o = valid_pipe[DELAY-1];
    assign data_o  = data_pipe[DELAY-1];
    assign mode_o  = mode_pipe[DELAY-1];

endmodule
