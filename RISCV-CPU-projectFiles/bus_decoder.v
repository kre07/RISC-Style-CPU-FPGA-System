module bus_decoder (
    input wire [31:0] addr, // Address the cpu is trying to access
    // cs = Chip Select
    output wire cs_bram,  // 1 = bram should respond
    output wire cs_vga,   // 1 = VGA memory should respond
    output wire cs_gpio   // 1 = GPIO/Buttons should respond
);


// This part means if the address is between 0x00000000 - 0x00001FFF, then select BRAM
    assign cs_bram =
        (addr >= 32'h00000000) &&
        (addr <= 32'h00001FFF);

// if the address is between h80000000 - h80001FFF, then select VGA
    assign cs_vga =
        (addr >= 32'h80000000) &&
        (addr <= 32'h80001FFF);

// if the address is exactly 32'h80003000, then select GPIO
    assign cs_gpio =
        (addr == 32'h80003000);


endmodule
