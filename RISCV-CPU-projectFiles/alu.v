module alu (
    input wire [31:0] a, // 32 bit value going into the ALU
    input wire [31:0] b, // 32 bit value going into the ALU
    input wire [3:0] alu_op, // Tells the Alu which operation to perform (ex. Add, Subtract, XOR, .. etc)
    output reg [31:0] result, // Output from ALU
    output wire zero
);
    // These are just names for the different 4-bit alu_op values
    // Example: alu_op = 0000 means ADD, alu_op = 0001 means Subtract
  
 

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
            // Shift a to the LEFT
            // b[4:0] tells it how many positions to shift
            // Only 5 bits are needed because a 32-bit number
            // can shift from 0 to 31 positions
            
            ALU_SRL:    result = a >> b[4:0];
            // Logical shift RIGHT, and puts 0s on the left
 
            
            ALU_SRA:    result = $signed(a) >>> b[4:0];
            // Also shifts right but this is for SIGNED NUMBERS (Negitaves and positives)
            
            ALU_SLT:    result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // Signed Comparison
                // SLT = Set Less Than
                // Treat a and b as SIGNED numbers
                // If a < b:
            // result = 1(True, A is less than B) 
                // Otherwise:
            // result = 0 (False, A is not less than B)
            ALU_SLTU:   result = (a < b) ? 32'd1 : 32'd0; // Unsigned Comparison
            // Same as SLT, but with unsigned numbers
            ALU_PASS_B: result = b;  // Send b directly to the output (No comparison)
            default:    result = 32'd0; // If the alu does not pick a operation, set result=0
        endcase
    end

    assign zero = (result == 32'd0);
    // If result is exactly 0:
    // zero = 1
    //
    // Otherwise:
    // zero = 0
    //
        
endmodule
