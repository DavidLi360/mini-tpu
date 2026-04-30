`timescale 1 ns / 1 ps

module control_fsm (
    input wire clk,
    input wire rst_n,
    input wire start,

    // outputs that control memory access
    output reg mem_we, // write enable for memory
    output reg [3:0] mem_addr, // address for memory access

    // outputs that control systolic array
    output reg array_en,
    output reg done // high when answer is ready
);

    localparam IDLE = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam DONE = 2'd2;

    reg [1:0] state;
    reg [3:0] step_counter; // track what cycle of computation we're on

    // state transition and counter logic
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            step_counter <= 4'd0;
        end else begin
            case(state)
                IDLE: begin
                    step_counter <= 4'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    if (step_counter == 4'd6) begin
                        state <= DONE;
                    end else begin
                        step_counter <= step_counter + 1'b1; // 4 bit adder
                    end
                end

                DONE: begin
                    state <= IDLE; // go back to idle after done
                end

                default: state <= IDLE;

            endcase
        end
    end


    // output combinational logic
    always @(*) begin
        mem_we = 1'b0;
        mem_addr = 4'd0;
        array_en = 1'b0;
        done = 1'b0;

        case (state)
            COMPUTE: begin
                // ask for data (control the memory address) based on step counter
                // ask for address 0 on cycle 1, address 1 on cycle 2, etc.
                if (step_counter < 4'd3) begin
                    mem_addr = step_counter;
                end else begin
                    mem_addr = 4'd3; 
                end
                // control systolic array enable signal
                // due to 1 cycle memory latency, dont turn on array until step 1
                // keep it on until step 6 to flush
                if (step_counter >= 4'd1 && step_counter <= 4'd6) begin
                    array_en = 1'b1;
                end
            end

            DONE: begin
                done = 1'b1;
            end

        endcase
    end 


endmodule