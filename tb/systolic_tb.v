`timescale 1 ns / 1ps

module systolic_tb;
    // inputs
    reg clk;
    reg rst_n;
    reg en;

    reg [7:0] left_A0;
    reg [7:0] left_A1;
    reg [7:0] top_B0;
    reg [7:0] top_B1;

    // outputs
    wire [15:0] result_00;
    wire [15:0] result_01;
    wire [15:0] result_10;
    wire [15:0] result_11;

    // unit under test (UUT)
    systolic_2x2 #(
        .IN_WIDTH(8),
        .OUT_WIDTH(16)
    ) uut(
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .left_A0(left_A0),
        .left_A1(left_A1),
        .top_B0(top_B0),
        .top_B1(top_B1),
        .result_00(result_00),
        .result_01(result_01),
        .result_10(result_10),
        .result_11(result_11)
    );

    always #10 clk = ~clk; // 50 MHz clock

    initial begin
        $dumpfile("systolic_wave.vcd");
        $dumpvars(0, systolic_tb);

        // initialize inputs
        clk = 0;
        rst_n = 0;
        en = 0;
        left_A0 = 0;
        left_A1 = 0;
        top_B0 = 0;
        top_B1 = 0;

        #40;
        rst_n = 1; // release reset
        #20;

        // cycle 1
        en = 1;
        left_A0 = 8'd1; // A00
        top_B0 = 8'd1;  // B00
        #20;

        // cycle 2
        en = 1;
        left_A0 = 8'd2; // A01
        top_B0 = 8'd0; // B10
        left_A1 = 8'd3; // A10 (start staggering in)
        top_B1 = 8'd0;  // B01 (start staggering in)
        #20;

        // cycle 3
        en = 1;
        left_A0 = 8'd0; // done with A00 and B00
        top_B0 = 8'd0; // done with A00 and B00
        left_A1 = 8'd4; // A11
        top_B1 = 8'd1;  // B11
        #20;

        // flush the pipeline with no new inputs
        en = 1;
        left_A0 = 8'd0; 
        top_B0 = 8'd0; 
        left_A1 = 8'd0; 
        top_B1 = 8'd0; 
        #20;
        #20;
        #20;

        $finish;
    end

    initial begin
        // continuously monitor and print to console throughout the simulation
        $monitor("Time: %0t | result_00: %d | result_01: %d | result_10: %d | result_11: %d", $time, result_00, result_01, result_10, result_11);
    end

endmodule
