module alu (
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [3:0] alu_op,
    output reg [31:0] result,
    output wire zero
);
    localparam ALU_ADD    = 4'b0000, 
               ALU_SUB    = 4'b0001, 
               ALU_AND    = 4'b0010,
               ALU_OR     = 4'b0011, 
               ALU_XOR    = 4'b0100, 
               ALU_SLL    = 4'b0101,
               ALU_SRL    = 4'b0110, 
               ALU_SRA    = 4'b0111, 
               ALU_SLT    = 4'b1000,
               ALU_SLTU   = 4'b1001,
               ALU_PASS_B = 4'b1010;

    always @(*) begin
        case (alu_op) // Depending on what operation you choose, it chooses an calculation from the list below
            ALU_ADD:    result = a + b;
            ALU_SUB:    result = a - b;
            ALU_AND:    result = a & b;
            ALU_OR:     result = a | b;
            ALU_XOR:    result = a ^ b;
            ALU_SLL:    result = a << b[4:0];
            ALU_SRL:    result = a >> b[4:0];
            ALU_SRA:    result = $signed(a) >>> b[4:0];
            ALU_SLT:    result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU:   result = (a < b) ? 32'd1 : 32'd0;
            ALU_PASS_B: result = b;
            default:    result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);
endmodule
