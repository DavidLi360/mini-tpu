`timescale 1 ns / 1 ps

module mini_tpu (
    input wire clk,
    input wire rst_n,
    input wire start,

    output wire done,
    output wire [15:0] result_00,
    output wire [15:0] result_01,
    output wire [15:0] result_10,
    output wire [15:0] result_11
);

    wire mem_we;
    wire [3:0] mem_addr;
    wire array_en;

    wire [31:0] mem_data_bus;

    bsram #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(4)
    ) memory_block (
        .clk(clk),
        .we(mem_we),
        .addr(mem_addr),
        .data_in(32'd0),
        .data_out(mem_data_bus)
    );

    control_fsm controller(
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .array_en(array_en),
        .done(done)
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

endmodule
