module pc_hw_test (
    input wire CLOCK_50,
    input wire KEY0, // active-low: manual clock step
    input wire KEY1, // active-low: reset
    output wire [9:0] LEDR // lower 10 bits of pc_out
);
    wire step = ~KEY0; // pressed = 1
    wire rst = ~KEY1;
    reg step_prev;
    wire step_edge = step & ~step_prev;
    
    always @(posedge CLOCK_50) step_prev <= step;

    wire [31:0] pc_val;
    pc dut (.clk(CLOCK_50), .rst(rst), .pc_write(step_edge),
            .branch_taken(1'b0), .branch_target(32'd0), .pc_out(pc_val));

    assign LEDR = pc_val[9:0];
endmodule