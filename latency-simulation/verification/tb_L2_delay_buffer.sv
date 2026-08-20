`timescale 1ns/1ps

module tb_L2_delay_buffer;

    localparam DATA_WIDTH = 64;
    localparam DELAY      = 3;

    // Clock / Reset
    logic clk;
    logic rst_n;

    // DUT inputs
    logic [DATA_WIDTH-1:0] data_i;
    logic                  valid_i;
    logic                  ready_i;

    // DUT outputs
    logic [DATA_WIDTH-1:0] data_o;
    logic                  valid_o;
    logic                  ready_o;

    //------------------------------------------------------------------
    // DUT
    //------------------------------------------------------------------

    L2_delay_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .DELAY(DELAY)
    ) dut (
        .clk_i   (clk),
        .rst_ni  (rst_n),

        .data_i  (data_i),
        .valid_i (valid_i),
        .ready_o (ready_o),

        .data_o  (data_o),
        .valid_o (valid_o),
        .ready_i (ready_i)
    );

    //------------------------------------------------------------------
    // Clock generation
    //------------------------------------------------------------------

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //------------------------------------------------------------------
    // VCD dump
    //------------------------------------------------------------------

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_L2_delay_buffer);
    end

    //------------------------------------------------------------------
    // Monitor
    //------------------------------------------------------------------

    always @(posedge clk) begin

        if (valid_i && ready_o)
            $display("[%0t] INPUT  data=%h",
                     $time, data_i);

        if (valid_o && ready_i)
            $display("[%0t] OUTPUT data=%h",
                     $time, data_o);

    end

    //------------------------------------------------------------------
    // Stimulus
    //------------------------------------------------------------------

    initial begin

        rst_n   = 0;

        data_i  = '0;
        valid_i = 0;

        ready_i = 1;

        // Reset
        repeat (5) @(posedge clk);

        rst_n = 1;

        $display("");
        $display("====================================");
        $display("TEST 1 : Single transaction");
        $display("====================================");
        $display("");

        @(posedge clk);
        data_i  <= 64'h0000000000001234;
        valid_i <= 1;

        @(posedge clk);
        valid_i <= 0;
        data_i  <= 0;

        repeat (10) @(posedge clk);

        $display("");
        $display("====================================");
        $display("TEST 2 : Multiple transactions");
        $display("====================================");
        $display("");

        @(posedge clk);
        valid_i <= 1;
        data_i  <= 64'hAAAA;

        @(posedge clk);
        data_i  <= 64'hBBBB;

        @(posedge clk);
        data_i  <= 64'hCCCC;

        @(posedge clk);
        valid_i <= 0;
        data_i  <= 0;

        repeat (10) @(posedge clk);

        $display("");
        $display("====================================");
        $display("TEST 3 : Backpressure");
        $display("====================================");
        $display("");

        @(posedge clk);
        valid_i <= 1;
        data_i  <= 64'hDEADBEEF;

        @(posedge clk);
        valid_i <= 0;

        // Bloque la sortie
        repeat (2) @(posedge clk);

        ready_i <= 0;

        repeat (5) @(posedge clk);

        ready_i <= 1;

        repeat (10) @(posedge clk);

        $display("");
        $display("Simulation completed");
        $display("");

        $finish;

    end

endmodule