module decoder (
    input wire [31:0] instr, // The 32 bit instruction currently being used
    output wire [6:0] opcode, // The general type of instruction (Load, store, branch, etc..)
    output wire [4:0] rd, // Register to write the result into
    output wire [4:0] rs1, // First register to read
    output wire [4:0] rs2, // Second register to read 
    output wire [2:0] funct3, // Used to store extra info about what instruction it is (Ex. Opcode tells us it is an R-Type instruction, and this might say this is adding, subtracting, etc.)
    output wire [6:0] funct7, // Used to store extra info about what instruction it is 
    output reg [31:0] imm, // Immediate Value
    output reg reg_write, // 1 = allow a value to be written into register rd, 0 = do not write to the register
    output reg mem_read, // 1 = Read from memory
    output reg mem_write, // 1 = write to memory
    output reg alu_src, // Chooses what goes into ALU input B. 0 = rs2_data, 1 = immediate value
    output reg branch, // 1 = branch instruction
    output reg [3:0] alu_op // Tells ALU.v what operation to perform
);
    // Giving names to different opcode values
    localparam OP_RTYPE  = 7'b0110011, OP_ITYPE = 7'b0010011, OP_LOAD  = 7'b0000011, // 0110011 = R-Type, ITYPE = 0010011, LOAD = 0000011
               OP_STORE  = 7'b0100011, OP_BRANCH= 7'b1100011, OP_LUI   = 7'b0110111,
               OP_AUIPC  = 7'b0010111, OP_JAL   = 7'b1101111, OP_JALR  = 7'b1100111;

 
    assign opcode = instr[6:0]; // Bits 6 to 0 of the instruction = opcode
    assign rd     = instr[11:7]; // Bits 11 to 7 of the instruction = destination register
    assign funct3 = instr[14:12]; // Bits 14 to 12 of the instruction = funct3
    assign rs1    = instr[19:15]; // Bits 19 to 15 of the instruction = first source register
    assign rs2    = instr[24:20]; // Bits 24 to 20 of the instruction = second source register
    assign funct7 = instr[31:25]; // Bits 31 to 25 of the instruction = funct7

    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};  // Builds the immediate for the I-Type instructions
    // Takes the 12-bit immediate from instr[31:20]
    // and makes it 32 bits.
    // instr[31] is the sign bit:
    // if it is 0, add 20 zeros to the front
    // if it is 1, add 20 ones to the front
    // This keeps positive/negative values correct.
    
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // Builds the immediate for Store instructions
    
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}; // Builds immediate for Branch Instructions
    
    wire [31:0] imm_u = {instr[31:12], 12'b0}; // Builds immediate for U-Type instructions
    
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}; // Builds immediate for Jump Instructions

    always @(*) begin // Whenever the instruction changes, recalculate all the control signals
        // The default values, start with everything being off (set to 0)
        // Then turn on based on only what the instruction needs
        imm       = 32'd0; 
        reg_write = 1'b0; 
        mem_read  = 1'b0; 
        mem_write = 1'b0;
        alu_src   = 1'b0; 
        branch    = 1'b0; 
        alu_op    = 4'b0000;

        case (opcode) // Look at the opcode and decide what kind of instruction it is
            OP_RTYPE: begin      
                reg_write = 1'b1; // R-Type instructions write the ALU result into destination register rd
                case ({funct7, funct3}) // Opcode tells us it is R-Type. funct7 + funct3 tell us the exact operation
                    10'b0000000_000: alu_op = 4'b0000; // ADD
                    10'b0100000_000: alu_op = 4'b0001; // SUB
                    10'b0000000_111: alu_op = 4'b0010; // AND
                    10'b0000000_110: alu_op = 4'b0011; // OR
                    10'b0000000_100: alu_op = 4'b0100; // XOR
                    10'b0000000_001: alu_op = 4'b0101; // SLL
                    10'b0000000_101: alu_op = 4'b0110; // SRL
                    10'b0100000_101: alu_op = 4'b0111; // SRA
                    10'b0000000_010: alu_op = 4'b1000; // SLT
                    10'b0000000_011: alu_op = 4'b1001; // SLTU

                    
                    default:         alu_op = 4'b0000; // If no match, default to Add
                endcase
            end
            OP_ITYPE: begin
                reg_write = 1'b1; // Result gets written into rd
                alu_src   = 1'b1; // ALU input B should use the immediate value
                imm       = imm_i; // Use the I-Type immediate
                case (funct3) // funct3 tells us the exact I-Type operation
                    3'b000:  alu_op = 4'b0000; // ADDI
                    3'b111:  alu_op = 4'b0010; // ANDI
                    3'b110:  alu_op = 4'b0011; // ORI
                    3'b100:  alu_op = 4'b0100; // XORI
                    3'b001:  alu_op = 4'b0101; // SLLI

                    
                    3'b101:  alu_op = (funct7 == 7'b0100000) ? 4'b0111 : 4'b0110; // If funct7 = 0100000, then go to SRAI, otherwise go to SRLI

                    
                    3'b010:  alu_op = 4'b1000; // SLTI
                    3'b011:  alu_op = 4'b1001; // SLTIU
                    default: alu_op = 4'b0000;
                endcase
            end

            
            OP_LOAD:   begin // LOAD PART
                reg_write = 1'b1; // Loaded value will be written into rd
                alu_src = 1'b1; // The ALU uses immediate as input B
                mem_read = 1'b1; // Read from memory
                imm = imm_i; // Use I-Type Immediate
                alu_op = 4'b0000; // Add rs1 + immediate, it calculates the memory address
            end
            
            OP_STORE:  begin 
                alu_src = 1'b1;   // ALU input B = immediate
                mem_write = 1'b1;  // Writes to memory
                imm = imm_s;  // Uses store immediate
                alu_op = 4'b0000;  // Add rs1 + immediate (Calculates memory address)
            end
            
            OP_BRANCH: begin 
                branch = 1'b1; // Tells the CPU this is a branch   
                imm = imm_b;  // Uses the branch immediate    
                alu_op = 4'b0001; // The ALU does A - B, if A - B = 0, then A and B are equal so it is useful for checking equality for example
                
            end
            OP_LUI:    begin // LUI = Load Upper Immediate
                reg_write = 1'b1; // Write result to rd
                alu_src = 1'b1;   // ALU input B = immediate
                imm = imm_u;   // Use the U-Type immediate
                alu_op = 4'b1010; // PASS_B, sends the immediate directly through the ALU
                
            end
            
            OP_AUIPC:  begin  // AUIPC = Add Upper Immediate to PC
                reg_write = 1'b1; // Result will be written to rd
                imm = imm_u; // Use the U-Type Immediate, and cpu_core.v handles PC + immediate
            end

            
            OP_JAL:   begin // JAL = Jump and Link
                reg_write = 1'b1; // Save the return address into rd
                imm = imm_j;  // Use the Jump immediate, it tells the CPU how far to jump and cpu_core.v handles the actual jump

            end
            
            OP_JALR:   begin // JALR = Jump and Link Register
                reg_write = 1'b1; // Save the return address into rd
                alu_src = 1'b1;   // The ALU uses immediate as input B
                imm = imm_i;  // Use the I-Type immediate, and cpu_core.v handles the jump target 
            end
            default:   ; // If opcode does not match, keep all the default values
        endcase
    end
endmodule
