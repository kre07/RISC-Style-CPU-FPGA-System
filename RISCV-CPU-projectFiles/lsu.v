module lsu (
    input wire [31:0] addr, // The memory address the CPU wants to access
    input wire [31:0] mem_rdata, // 32 bit data coming FROM memory
    input wire [2:0] funct3, // Tells the LSU what kind of load/store it is, ex. LB = Load Byte, LH, LW, SB, SH, SW
    input wire [31:0] store_data, // The data the CPU wants to write into memory 
    output reg [31:0] load_result, // Final value that gets sent back to the CPU after a load
    output reg [31:0] mem_wdata, // Data prepared to be written into memory
    output reg [3:0] mem_byte_en // Controls which bytes of the 32 bit memory word should be written
);
    wire [1:0] byte_off = addr[1:0];
    // Uses the last 2 bits of the address to decide which byte inside the 32 bit word we want 
    // 00 = first byte, 01 = second byte, 10 = third/ 11 = fourth

    always @(*) begin // Part 1:LOAD LOGIC begins here (Decides what data should come out when reading memory)
                      // Load reads the data from the memory into a CPU Register

        
        case (funct3) // PART 2: : Load Byte (Load Byte: Select 1 of 4 possible 8-bit bytes, Then sign extend it to 32 bits after you selected one)
            //// Memory returns 32 bits, but LB only needs one byte (8 bits). Select the byte using byte_off, then copy its sign bit into
                    
                        
            3'b000: case (byte_off) // LB = Load Byte,  ( byte_off selects one of the four bytes; the other three are ignored for this load bc LB = Just select 1 byte, as 4 Bytes = word)
                2'd0: load_result = {{24{mem_rdata[7]}}, mem_rdata[7:0]}; // Load the first byte, which has 7:0 bits. Also the sign extends it to 32 bits
                2'd1: load_result = {{24{mem_rdata[15]}}, mem_rdata[15:8]}; // Load the second byte
                2'd2: load_result = {{24{mem_rdata[23]}}, mem_rdata[23:16]}; // Load Third byte
                2'd3: load_result = {{24{mem_rdata[31]}}, mem_rdata[31:24]}; // Load fourth byte
            endcase
            3'b100: case (byte_off) // LBU = Load Byte Unsigned (Choose one of the Possible 
                2'd0: load_result = {24'd0, mem_rdata[7:0]}; // Filling the upper bits with 24 0's, and the rest of the bits come from 7:0. 24 + 8 = 32
                2'd1: load_result = {24'd0, mem_rdata[15:8]}; // Same
                2'd2: load_result = {24'd0, mem_rdata[23:16]}; // Same
                2'd3: load_result = {24'd0, mem_rdata[31:24]}; // Same
            endcase



//PART 2: Load Half word and Load Halfword Unsigned    
            
            // LH = Load Halfword is below
            // It loads 16 buts, then the sign extends it to 32 bits
            3'b001: load_result = byte_off[1] ? {{16{mem_rdata[31]}}, mem_rdata[31:16]} // 31:16 has 16 bits, and the other 16 is from the {16{mem_rdata[31]}} Same thing below
                                              : {{16{mem_rdata[15]}}, mem_rdata[15:0]}; 

            
            // LHU = Load Halfword Unsigned is below . It loads the 16 buts, and the upper 16 bits just become 0.
            3'b101: load_result = byte_off[1] ? {16'd0, mem_rdata[31:16]} 
                                              : {16'd0, mem_rdata[15:0]}; // LHU
            default: load_result = mem_rdata; // LW = Load Word (In defualt just use the entire 32 bit memory value)
        endcase
    end
    


    // PART 3: Store Logic; Writes the data from a CPU Register into Memory
    always @(*) begin 
        case (funct3)

            3'b000: begin // Part 1: SB (Store Byte)

                mem_wdata = {4{store_data[7:0]}};
                // Takes the lowest 8 bits of store_data
                // and copies them 4 times across the 32-bit value

                mem_byte_en = 4'b0001 << byte_off;
                // Enables only ONE byte position
                //
                // byte_off = 0 -> 0001
                // byte_off = 1 -> 0010
                // byte_off = 2 -> 0100
                // byte_off = 3 -> 1000

            end

            3'b001: begin //  Part 2: SH (Store Halfword)

                mem_wdata = {2{store_data[15:0]}};
                // Takes lowest 16 bits
                // and copies them twice

                mem_byte_en =
                    byte_off[1] ? 4'b1100 : 4'b0011;
                // Chooses which 2 bytes should be written

            end


            default: begin // Part 3: SW (Store Word)

                mem_wdata = store_data;
                // Write all 32 bits

                mem_byte_en = 4'b1111;
                // Enable all 4 bytes

            end

        endcase
    end

endmodule
