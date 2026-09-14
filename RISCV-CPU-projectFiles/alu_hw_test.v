module alu_hw_test (
    input wire [9:0] SW,      // SW[3:0]=alu_op, SW[9:4] unused here
    output wire [9:0] LEDR    // lower 10 bits of result; use two runs to check full 32-bit values
);
    wire [31:0] result;
    wire zero;
    
    // Hardwire small test operands for a quick sanity check (10 and 3)
    alu dut (.a(32'd10), .b(32'd3), .alu_op(SW[3:0]), .result(result), .zero(zero));
    
    assign LEDR = result[9:0];
endmodule


 


