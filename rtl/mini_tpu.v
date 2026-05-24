`timescale 1 ns / 1 ps

module mini_tpu (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire dummy_in,  // NEW: 1-bit fake data input

    output wire done,
    output wire dummy_out
);

    wire mem_we;
    wire [3:0] mem_addr;
    wire array_en;
    
    (* syn_keep = 1 *) wire [31:0] mem_data_bus;

    (* syn_keep = 1 *) wire [15:0] result_00;
    (* syn_keep = 1 *) wire [15:0] result_01;
    (* syn_keep = 1 *) wire [15:0] result_10;
    (* syn_keep = 1 *) wire [15:0] result_11;

    control_fsm controller(
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .array_en(array_en),
        .done(done)
    );

    bsram #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(4)
    ) memory_block (
        .clk(clk),
        .we(mem_we),
        .addr(mem_addr),
        // THE TRICK: Replicate the 1-bit dummy input 32 times
        // The compiler must build the RAM because it can't predict this pin!
        .data_in({32{dummy_in}}), 
        .data_out(mem_data_bus)
    );

    systolic_2x2 array (
        .clk(clk),
        .rst_n(rst_n),
        .en(array_en),
        
        .left_A0(mem_data_bus[31:24]), 
        .left_A1(mem_data_bus[23:16]), 
        .top_B0(mem_data_bus[15:8]),   
        .top_B1(mem_data_bus[7:0]),    
        
        .result_00(result_00),
        .result_01(result_01),
        .result_10(result_10),
        .result_11(result_11)
    );

    // The XOR reduction tree
    assign dummy_out = ^result_00 ^ ^result_01 ^ ^result_10 ^ ^result_11;

endmodule