`timescale 1ns / 1ps

/*
 * module: mac (multiply-accumulate)
 * description: 8-bit MAC unit for a Systolic Array
 * multiplies two 8-bit inputs and adds to a 16-bit accumulator.
 */

module mac (
    input wire clk,              
    input wire rst_n,            // active low synch reset
    input wire en,        
    // 8 bit inputs       
    input wire [7:0] a,         
    input wire [7:0] b,          
    // 16 bit output
    output reg [15:0] result     
);

    always @(posedge clk) begin
        if (!rst_n) begin
            result <= 16'b0; // reset accumulator to zero when reset is pulled low
        end else if (en) begin
            result <= result + (a * b); // when enabled, multiply a and b and accumulate the result
        end
    end

endmodule