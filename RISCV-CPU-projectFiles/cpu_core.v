module cpu_core (
    // Part 1: Main CPU inputs/Outputs
    input wire clk, // CPU clock
    input wire rst, // Reset
    input wire [31:0] instr, // Current 32 bit instruction from BRAM
    input wire [31:0] mem_rdata, // Data coming back from memory
    output wire [31:0] pc_out, //Current PC address
    output wire mem_read, // 1 = read memory
    output wire mem_write, // 1 = write memory
    output wire [31:0] mem_addr, // Address the CPU wants to address
    output wire [31:0] mem_wdata, // The data CPU wants to write
    output wire [3:0] mem_byte_en // Which bytes should be written
);
    // Part 2: The instruction pieces coming from decoder.v
    wire [6:0] opcode, funct7; // opcode = general instruction type
    wire [4:0] rd, rs1, rs2; // destination reg, first source reg , second source reg
    wire [2:0] funct3; // func3/func7 = exact operation

    wire [31:0] imm, rs1_data, rs2_data, alu_result, load_result; // immidiate value, value stored in reg 1,...
   
    wire 
    reg_write,  // can write to rd
    alu_src,  // ALU B uses rs2 or immediate
    branch, zero;
    
    wire [3:0] alu_op;


// Part 3: DECODER
    // Basically sends all the instructions into the decoder, and gets all the control signals and register addresses back
    decoder dec_inst (
        .instr(instr), .opcode(opcode), .rd(rd), .rs1(rs1), .rs2(rs2), 
        .funct3(funct3), .funct7(funct7), .imm(imm), .reg_write(reg_write), 
        .mem_read(mem_read), .mem_write(mem_write), .alu_src(alu_src), 
        .branch(branch), .alu_op(alu_op)
    );

    // Part 4: Branch Condition
    // The whole segment ask "Should the branch even happen?" (Remember the branch is just evaluating the registers)
    reg branch_cond;
    always @(*) begin
        case (funct3)
            3'b000: branch_cond = zero;                                       // BEQ = Branch if Equal (rs1-rs2 = 5 - 5 = 0) so if equal, itll be 0
            3'b001: branch_cond = !zero;                                      // BNE = Branch if Not Equal
            3'b100: branch_cond = ($signed(rs1_data) < $signed(rs2_data));   // BLT = Branch if Less Than
            3'b101: branch_cond = ($signed(rs1_data) >= $signed(rs2_data));  // BGE = Branch if greater than or equal to
            3'b110: branch_cond = (rs1_data < rs2_data);                     // BLTU = Branch less than unsigned
            3'b111: branch_cond = (rs1_data >= rs2_data);                    // BGEU = Branch greater than or equal to Unsigned
            default: branch_cond = 1'b0;
        endcase
    end

    // Part 4: Simple yes/no checks
    // Ex if opcode = JAL opcode, then is_jal = 1 (yes)
    wire is_jal   = (opcode == 7'b1101111);
    wire is_jalR  = (opcode == 7'b1100111);
    wire is_auipc = (opcode == 7'b0010111);


    // Part 5: Branch conditions
    // Take the jump if normal branch and condition is true 
    // OR the instruction is is_jal is true OR instruction is is_jalR
    wire branch_taken = (branch & branch_cond) | is_jal | is_jalR; 

    // Part 6: Deciding where to jump
    // JALR = rs1_data + imm, other = pc_out + imm
    wire [31:0] branch_target = is_jalR ? (rs1_data + imm) : (pc_out + imm);


    // Part 6: PC Module
    pc pc_inst (
        .clk(clk), .rst(rst), .pc_write(1'b1), // pc_write allows all the pc to be updated
        .branch_taken(branch_taken), .branch_target(branch_target), 
        .pc_out(pc_out)
    ); // so every clock if branch_taken = 0, then PC + 4. IF branch_taken = 1, then branch_target (whatever it is ).

    wire [31:0] rd_data = (is_jal | is_jalR) ? (pc_out + 32'd4) :
                          is_auipc           ? (pc_out + imm)   :
                          mem_read           ? load_result      : 
                                               alu_result;
    
    reg_file reg_inst (
        .clk(clk), .rst(rst), .we(reg_write), .rs1_addr(rs1), 
        .rs2_addr(rs2), .rd_addr(rd), .rd_data(rd_data), 
        .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    wire [31:0] b_in = alu_src ? imm : rs2_data;
    
    alu alu_inst (
        .a(rs1_data), .b(b_in), .alu_op(alu_op), 
        .result(alu_result), .zero(zero)
    );

    lsu lsu_inst (
        .addr(alu_result), .mem_rdata(mem_rdata), .funct3(funct3), 
        .store_data(rs2_data), .load_result(load_result), 
        .mem_wdata(mem_wdata), .mem_byte_en(mem_byte_en)
    );

    assign mem_addr = alu_result;
endmodule
