module cpu_core (
    input wire clk,
    input wire rst,
    input wire [31:0] instr,
    input wire [31:0] mem_rdata,
    output wire [31:0] pc_out,
    output wire mem_read,
    output wire mem_write,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [3:0] mem_byte_en
);
    wire [6:0] opcode, funct7;
    wire [4:0] rd, rs1, rs2;
    wire [2:0] funct3;
    wire [31:0] imm, rs1_data, rs2_data, alu_result, load_result;
    wire reg_write, alu_src, branch, zero;
    wire [3:0] alu_op;

    decoder dec_inst (
        .instr(instr), .opcode(opcode), .rd(rd), .rs1(rs1), .rs2(rs2), 
        .funct3(funct3), .funct7(funct7), .imm(imm), .reg_write(reg_write), 
        .mem_read(mem_read), .mem_write(mem_write), .alu_src(alu_src), 
        .branch(branch), .alu_op(alu_op)
    );

    reg branch_cond;
    always @(*) begin
        case (funct3)
            3'b000: branch_cond = zero;                                       // BEQ
            3'b001: branch_cond = !zero;                                      // BNE
            3'b100: branch_cond = ($signed(rs1_data) < $signed(rs2_data));   // BLT
            3'b101: branch_cond = ($signed(rs1_data) >= $signed(rs2_data));  // BGE
            3'b110: branch_cond = (rs1_data < rs2_data);                     // BLTU
            3'b111: branch_cond = (rs1_data >= rs2_data);                    // BGEU
            default: branch_cond = 1'b0;
        endcase
    end

    wire is_jal   = (opcode == 7'b1101111);
    wire is_jalR  = (opcode == 7'b1100111);
    wire is_auipc = (opcode == 7'b0010111);

    wire branch_taken = (branch & branch_cond) | is_jal | is_jalR;
    wire [31:0] branch_target = is_jalR ? (rs1_data + imm) : (pc_out + imm);
    
    pc pc_inst (
        .clk(clk), .rst(rst), .pc_write(1'b1), 
        .branch_taken(branch_taken), .branch_target(branch_target), 
        .pc_out(pc_out)
    );

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