`timescale 1 ns / 1 ps

module bsram_tb;
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;

    // signals
    reg clk;
    reg we; // write enable
    reg [ADDR_WIDTH-1:0] addr;
    reg [DATA_WIDTH-1:0] data_in;

    wire [DATA_WIDTH-1:0] data_out;

    // unit under test (UUT)
    bsram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .we(we),
        .addr(addr),
        .data_in(data_in),
        .data_out(data_out)
    );

    // clock = 50 MHz
    always #10 clk = ~clk; 

    initial begin
        $dumpfile("bsram_wave.vcd");
        $dumpvars(0, bsram_tb);

        // initialize signals
        clk = 0;
        we = 0;
        addr = 4'd0;
        data_in = 8'd0;

        #30;

        // write to memory
        $display("Writing to memory...");
        we = 1; // enable write

        // write 10 into address 0
        addr = 4'd0;
        data_in = 8'd10;
        #20; // wait one clock cycle for the write to complete

        // write 20 into address 1
        addr = 4'd1;
        data_in = 8'd20;
        #20;

        // write 30 into address 2
        addr = 4'd2;
        data_in = 8'd30;
        #20;

        // write 40 into address 3
        addr = 4'd3;
        data_in = 8'd40;
        #20;

        // read from memory
        $display("Reading from memory...");
        we = 0; // disable write to read

        // read from address 0
        addr = 4'd0;
        #20; // wait one clock cycle for the read to complete
        $display("Time: %0t | Addr: 0 | Read Data: %d", $time, data_out);

        // read from address 1
        addr = 4'd1;
        #20;
        $display("Time: %0t | Addr: 1 | Read Data: %d", $time, data_out);

        // read from address 2
        addr = 4'd2;
        #20;
        $display("Time: %0t | Addr: 2 | Read Data: %d", $time, data_out);

        // read from address 3
        addr = 4'd3;
        #20;
        $display("Time: %0t | Addr: 3 | Read Data: %d", $time, data_out);

        #40;
        $display("Testbench completed");

        $finish; // end simulation
    end

endmodule