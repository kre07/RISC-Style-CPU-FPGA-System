module bram (
    input wire clk,

    // =========================================================
    // PORT A - CPU INSTRUCTION FETCH
    // =========================================================
    input wire [10:0] addr_a,
    output wire [31:0] rdata_a,

    // =========================================================
    // PORT B - CPU DATA MEMORY
    // =========================================================
    input wire [10:0] addr_b,
    input wire [31:0] wdata_b,
    input wire we_b,
    output reg [31:0] rdata_b
);


    // =========================================================
    // INSTRUCTION ROM
    // =========================================================
    //
    // Your current game = 112 instructions/words.
    // 128 entries is enough.
    //
    // Keep asynchronous instruction read because your CPU
    // currently expects the instruction combinationally.
    // =========================================================

    reg [31:0] inst_rom [0:127];


    // =========================================================
    // SMALL DATA RAM
    // =========================================================
    //
    // We do NOT need 2048 x 32-bit registers.
    //
    // Your program mainly needs:
    //
    //    globals around address 0x1B8
    //    stack around address 0x1FD0 - 0x1FFF
    //
    // We use the lower 7 address bits so the high stack
    // addresses wrap into this small physical RAM.
    //
    // 128 words x 32 bits = only 4096 bits.
    // =========================================================

    reg [31:0] data_ram [0:127];


    integer i;

    initial begin

        // -----------------------------------------------------
        // Default instruction = RISC-V NOP
        // -----------------------------------------------------

        for (i = 0; i < 128; i = i + 1) begin
            inst_rom[i] = 32'h00000013;
            data_ram[i] = 32'h00000000;
        end


        // -----------------------------------------------------
        // Load game instructions
        // -----------------------------------------------------

        $readmemh("game_words.hex", inst_rom);


        // -----------------------------------------------------
        // Initialized C global variables
        // -----------------------------------------------------
        //
        // 0x1B8 / 4 = word address 110
        //
        // volatile char *VGA_MEM =
        //                  (volatile char *)0x80000000;
        //
        data_ram[7'd110] = 32'h80000000;


        // 0x1BC / 4 = word address 111
        //
        // volatile int *GPIO_IN =
        //                  (volatile int *)0x80003000;
        //
        data_ram[7'd111] = 32'h80003000;

    end



    // =========================================================
    // INSTRUCTION FETCH
    // =========================================================

    assign rdata_a = inst_rom[addr_a[6:0]];



    // =========================================================
    // DATA RAM
    // =========================================================
    //
    // IMPORTANT:
    //
    // addr_b is 11 bits because the original address space
    // supported 2048 words.
    //
    // We only use the LOWER 7 bits.
    //
    // Example:
    //
    // stack address:
    // 0x1FF0 / 4 = 0x7FC
    //
    // lower 7 bits of 0x7FC = 0x7C
    //
    // so it maps safely into our 128-word physical RAM.
    // =========================================================

    always @(posedge clk) begin

        if (we_b) begin
            data_ram[addr_b[6:0]] <= wdata_b;
        end

        rdata_b <= data_ram[addr_b[6:0]];

    end


endmodule