module lsu (
    input wire [31:0] addr,
    input wire [31:0] mem_rdata,
    input wire [2:0] funct3,
    input wire [31:0] store_data,
    output reg [31:0] load_result,
    output reg [31:0] mem_wdata,
    output reg [3:0] mem_byte_en
);
    wire [1:0] byte_off = addr[1:0];

    always @(*) begin
        case (funct3)
            3'b000: case (byte_off) // LB
                2'd0: load_result = {{24{mem_rdata[7]}}, mem_rdata[7:0]};
                2'd1: load_result = {{24{mem_rdata[15]}}, mem_rdata[15:8]};
                2'd2: load_result = {{24{mem_rdata[23]}}, mem_rdata[23:16]};
                2'd3: load_result = {{24{mem_rdata[31]}}, mem_rdata[31:24]};
            endcase
            3'b100: case (byte_off) // LBU
                2'd0: load_result = {24'd0, mem_rdata[7:0]};
                2'd1: load_result = {24'd0, mem_rdata[15:8]};
                2'd2: load_result = {24'd0, mem_rdata[23:16]};
                2'd3: load_result = {24'd0, mem_rdata[31:24]};
            endcase
            3'b001: load_result = byte_off[1] ? {{16{mem_rdata[31]}}, mem_rdata[31:16]} 
                                              : {{16{mem_rdata[15]}}, mem_rdata[15:0]}; // LH
            3'b101: load_result = byte_off[1] ? {16'd0, mem_rdata[31:16]} 
                                              : {16'd0, mem_rdata[15:0]}; // LHU
            default: load_result = mem_rdata; // LW
        endcase
    end

    always @(*) begin
        case (funct3)
            3'b000: begin mem_wdata = {4{store_data[7:0]}}; mem_byte_en = 4'b0001 << byte_off; end // SB
            3'b001: begin mem_wdata = {2{store_data[15:0]}}; mem_byte_en = byte_off[1] ? 4'b1100 : 4'b0011; end // SH
            default: begin mem_wdata = store_data; mem_byte_en = 4'b1111; end // SW
        endcase
    end
endmodule