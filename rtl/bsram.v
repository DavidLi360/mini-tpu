`timescale 1 ns / 1 ps

module bsram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input wire clk,
    input wire we, // write enable
    input wire [ADDR_WIDTH-1:0] addr,
    // data to write to memory
    input wire [DATA_WIDTH-1:0] data_in,

    // data read from memory
    output reg [DATA_WIDTH-1:0] data_out
);

    localparam RAM_DEPTH = 1 << ADDR_WIDTH; // calculate depth before declaring memory array

    reg [DATA_WIDTH-1:0] ram_block [0:RAM_DEPTH-1]; // declare memory block (array of registers)

    always @(posedge clk) begin
        if (we) begin
            // write mode: put data_in into specific memory address
            ram_block[addr] <= data_in;
        end else begin
            // read mode: output data from specific memory address
            data_out <= ram_block[addr];
        end
    end

endmodule
