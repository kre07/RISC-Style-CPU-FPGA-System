module decoder (
    input wire [31:0] instr, // The 32 bit instruction currently being used
    output wire [6:0] opcode, // The general type of instruction (Load, store, branch, etc..)
    output wire [4:0] rd, // Register to write the restlt into
    output wire [4:0] rs1, // First register to read
    output wire [4:0] rs2, // Second register to read 
    output wire [2:0] funct3, // Used to store extra info about what instrution it is  (Ex. Op code tells us its R-Type instruction, and this might say this is adding, or subtracting, etc.)
    output wire [6:0] funct7, // Used to store extra info about what instrution it is 
    output reg [31:0] imm, // Immidiate Value
    output reg reg_write,
    output reg mem_read,
    output reg mem_write,
    output reg alu_src,
    output reg branch,
    output reg [3:0] alu_op
);
    localparam OP_RTYPE  = 7'b0110011, OP_ITYPE = 7'b0010011, OP_LOAD  = 7'b0000011,
               OP_STORE  = 7'b0100011, OP_BRANCH= 7'b1100011, OP_LUI   = 7'b0110111,
               OP_AUIPC  = 7'b0010111, OP_JAL   = 7'b1101111, OP_JALR  = 7'b1100111;

    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    always @(*) begin
        imm       = 32'd0; 
        reg_write = 1'b0; 
        mem_read  = 1'b0; 
        mem_write = 1'b0;
        alu_src   = 1'b0; 
        branch    = 1'b0; 
        alu_op    = 4'b0000;

        case (opcode)
            OP_RTYPE: begin
                reg_write = 1'b1;
                case ({funct7, funct3})
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
                    default:         alu_op = 4'b0000;
                endcase
            end
            OP_ITYPE: begin
                reg_write = 1'b1; 
                alu_src   = 1'b1; 
                imm       = imm_i;
                case (funct3)
                    3'b000:  alu_op = 4'b0000; // ADDI
                    3'b111:  alu_op = 4'b0010; // ANDI
                    3'b110:  alu_op = 4'b0011; // ORI
                    3'b100:  alu_op = 4'b0100; // XORI
                    3'b001:  alu_op = 4'b0101; // SLLI
                    3'b101:  alu_op = (funct7 == 7'b0100000) ? 4'b0111 : 4'b0110; // SRAI / SRLI
                    3'b010:  alu_op = 4'b1000; // SLTI
                    3'b011:  alu_op = 4'b1001; // SLTIU
                    default: alu_op = 4'b0000;
                endcase
            end
            OP_LOAD:   begin reg_write = 1'b1; alu_src = 1'b1; mem_read = 1'b1; imm = imm_i; alu_op = 4'b0000; end
            OP_STORE:  begin alu_src = 1'b1;   mem_write = 1'b1; imm = imm_s;  alu_op = 4'b0000; end
            OP_BRANCH: begin branch = 1'b1;    imm = imm_b;      alu_op = 4'b0001; end
            OP_LUI:    begin reg_write = 1'b1; alu_src = 1'b1;   imm = imm_u;  alu_op = 4'b1010; end
            OP_AUIPC:  begin reg_write = 1'b1; imm = imm_u; end
            OP_JAL:    begin reg_write = 1'b1; imm = imm_j; end
            OP_JALR:   begin reg_write = 1'b1; alu_src = 1'b1;   imm = imm_i; end
            default:   ; 
        endcase
    end
endmodule
