`timescale 1 ns / 1 ps

module control_fsm_tb;
    reg clk;
    reg rst_n;
    reg start;

    wire mem_we;
    wire [3:0] mem_addr;
    wire array_en;
    wire done;

    control_fsm uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .array_en(array_en),
        .done(done)
    );

    // clock generation: 50 MHz
    always #10 clk = ~clk; // toggle clock every 10 ns

    initial begin
        $dumpfile("control_fsm_wave.vcd");
        $dumpvars(0, control_fsm_tb);

        clk = 0;
        rst_n = 0; 
        start = 0;

        #40;
        rst_n = 1;
        #20;

        // pulse start signal to begin computation
        start = 1;
        #20; // one clock cycle
        start = 0; 

        // let it run
        #200; 

        $display("Test complete.");
        $finish;
    end

    initial begin
        $monitor("Time: %0t | State: %b | Step: %d || Mem Addr: %d | Array En: %b | Done: %b", $time, uut.state, uut.step_counter, mem_addr, array_en, done);
    end
endmodule