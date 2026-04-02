// sets the time unit for simulation (1 ns) and precision (1 ps)
`timescale 1 ns / 1ps

// define module for a 2x2 systolic array of MAC units
module systolic_2x2 #(
    parameter IN_WIDTH = 8,
    parameter OUT_WIDTH = 16 // 16 bits to prevent overflow
)(
    // system control signals
    input wire clk,
    input wire rst_n,
    input wire en,

    // data inputs (edges of the array)
    input wire [IN_WIDTH-1:0] left_A0,
    input wire [IN_WIDTH-1:0] left_A1,
    input wire [IN_WIDTH-1:0] top_B0,
    input wire [IN_WIDTH-1:0] top_B1,

    // data outputs (final accumulated matrix values)
    output wire [OUT_WIDTH-1:0] result_00,
    output wire [OUT_WIDTH-1:0] result_01,
    output wire [OUT_WIDTH-1:0] result_10,
    output wire [OUT_WIDTH-1:0] result_11
);

    // the internal pipeline registers to hold intermediate values for one clock cycle
    reg [IN_WIDTH-1:0] a_delay_00, a_delay_10;
    reg [IN_WIDTH-1:0] b_delay_00, b_delay_01;

    // clocking block
    always @(posedge clk) begin
        if (!rst_n) begin
            // reset is pulled low so we clear the pipeline registers to zero
            a_delay_00 <= {IN_WIDTH{1'b0}};
            a_delay_10 <= {IN_WIDTH{1'b0}};
            b_delay_00 <= {IN_WIDTH{1'b0}};
            b_delay_01 <= {IN_WIDTH{1'b0}};
        end else if (en) begin

            // when enabled, grab incoming edge data and store for next cycle 
            // pass A data to right and B data downwards in the array
            a_delay_00 <= left_A0;
            b_delay_00 <= top_B0;

            a_delay_10 <= left_A1;
            b_delay_01 <= top_B1;
        end
    end

    // top left, takes inputs instantly  
    mac #(
        .IN_WIDTH(IN_WIDTH), .OUT_WIDTH(OUT_WIDTH)
    ) mac_00 (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .a(left_A0),  
        .b(top_B0),  
        .result(result_00)
    );

    // top right, takes A from left and B from top with one cycle delay
    mac #(
        .IN_WIDTH(IN_WIDTH), .OUT_WIDTH(OUT_WIDTH)
    ) mac_01 (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .a(a_delay_00), 
        .b(top_B1),    
        .result(result_01)
    );

    // bottom left, takes A from left and B from top with one cycle delay
    mac #(
        .IN_WIDTH(IN_WIDTH), .OUT_WIDTH(OUT_WIDTH)
    ) mac_10 (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .a(left_A1),
        .b(b_delay_00), 
        .result(result_10)
    );

    // bottom right, takes A from left and B from top with one cycle delay
    mac #(
        .IN_WIDTH(IN_WIDTH), .OUT_WIDTH(OUT_WIDTH)
    ) mac_11 (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .a(a_delay_10), 
        .b(b_delay_01), 
        .result(result_11)
    );


endmodule