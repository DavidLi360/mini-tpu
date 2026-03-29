`timescale 1ns / 1ps

module mac_tb;

    // we denote inputs to module as reg (we drive them)
    reg clk;
    reg rst_n;
    reg en;
    reg [7:0] a;
    reg [7:0] b;
    
    // outputs are denoted by wire (we observe them)
    wire [15:0] result;

    // unit under test (UUT)
    mac uut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .a(a),
        .b(b),
        .result(result)
    );

    // clock generation: 50 MHz (20 ns period)
    always #10 clk = ~clk; // toggle clock every 10 ns

    // test sequence
    initial begin
        // dump waveforms 
        $dumpfile("mac_wave.vcd");
        $dumpvars(0, mac_tb);

        // initialize inputs
        clk = 0;
        rst_n = 0; 
        en = 0;
        a = 0;
        b = 0;

        #40;
        rst_n = 1; // release reset
        #20;


        // test case 1: simple multiplication 
        // 2 * 3 = 6
        en = 1; 
        a = 8'd2;
        b = 8'd3;
        #20; // one clock cycle


        // test case 2: accumulation
        // add 4 * 5 = 20 to previous result (6 + 20 = 26)
        en = 1;
        a = 8'd4;
        b = 8'd5;
        #20;

        // test case 3: disable enable pin
        // it should hold prev result (26) when en is low
        en = 0;
        a = 8'd10; // changed inputs which should not change result
        b = 8'd10;
        #20;

        // test case 4: max 8 bit values
        // add 255 * 255 = 65025 to previous result (26 + 65025 = 65051)
        en = 1;
        a = 8'd255;
        b = 8'd255;
        #20;

        #40;
        $display("Testbench completed");
        $finish; // end simulation
    end

initial begin
    $monitor("Time=%0t | rst_n=%b | en=%b | a=%3d | b=%3d || result=%5d", $time, rst_n, en, a, b, result); // monitor changes in inputs and output
end

endmodule
