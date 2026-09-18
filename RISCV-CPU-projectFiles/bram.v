module bram (
    input wire clk,
// Part 1: Port A >> used to READ instructions
    input wire [10:0] addr_a, // instruction address
    output wire [31:0] rdata_a, // the instruction that comes out 
 
    // Part 2: PORT B >> used for data memory for reading/writing ( The data memory in bram can be read from or written to)

    input wire [10:0] addr_b, // the data memory address
    input wire [31:0] wdata_b, // the data CPU wants to write (w = write)
    input wire we_b, // Write enable
    output reg [31:0] rdata_b // Data coming back from memory ( r = read)
);



    reg [31:0] inst_rom [0:127]; // 128 instruction locations, each location stores 32 bits. // instruction memory

    reg [31:0] data_ram [0:127]; // 128 data locations, each location stores 32 bits // data memory


    integer i;

    initial begin

        // -----------------------------------------------------
        // Default instruction = RISC-V NOP
        // -----------------------------------------------------

        for (i = 0; i < 128; i = i + 1) begin
            inst_rom[i] = 32'h00000013;
            data_ram[i] = 32'h00000000;
        end


        $readmemh("game_words.hex", inst_rom);  // Load machine code instructions from game_words into instruction memory.

        data_ram[7'd110] = 32'h80000000;

        data_ram[7'd111] = 32'h80003000;

    end





    assign rdata_a = inst_rom[addr_a[6:0]]; // Important part (Basically spitting out the instruction)
    // Take instruction address >> pick one location in inst_rom >> output that instruction as rdata_a
    // only addr_a[6:0] is used because 7 bits can select 0-127



// Part 4: The data-memory part 

    // if we_b = 1 → write wdata_b (the data the CPU wants to write) into data_ram
    //  and 
    // read the selected memory location → send it to rdata_b (Data coming back from memory)

    always @(posedge clk) begin

        if (we_b) begin
            data_ram[addr_b[6:0]] <= wdata_b;
        end

        rdata_b <= data_ram[addr_b[6:0]];

    end


endmodule
