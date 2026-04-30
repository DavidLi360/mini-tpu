`timescale 1 ns / 1ps

module mini_tpu_tb;

    reg clk;
    reg rst_n;
    reg start;
    
    wire done;
    wire [15:0] result_00;
    wire [15:0] result_01;
    wire [15:0] result_10;
    wire [15:0] result_11;

    mini_tpu uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .result_00(result_00),
        .result_01(result_01),
        .result_10(result_10),
        .result_11(result_11)
    );

    // clock generation (50 MHz)
    always #10 clk = ~clk;

    initial begin
        $dumpfile("tpu_wave.vcd");
        $dumpvars(0, mini_tpu_tb);

        // injects our hex file directly into the memory block
        $readmemh("tb/matrix_data.hex", uut.memory_block.ram_block);

        clk = 0;
        rst_n = 0;
        start = 0;

        #40;
        rst_n = 1; 
        #20;

        $display("=================================================");
        $display(" STARTING MINI-TPU MATRIX MULTIPLICATION");
        $display("=================================================");

        start = 1;
        #20;
        start = 0;

        wait(done == 1'b1);
        
        #20;

        // Print the final output matrix
        $display("=================================================");
        $display(" CALCULATION COMPLETE. FINAL MATRIX:");
        $display(" [%2d, %2d]", result_00, result_01);
        $display(" [%2d, %2d]", result_10, result_11);
        $display("=================================================");
        
        $finish;
    end

endmodule