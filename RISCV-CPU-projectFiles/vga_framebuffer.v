module vga_framebuffer (
    input wire clk,

    // CPU Interface
    input wire cpu_we,
    input wire [12:0] cpu_addr,
    input wire [7:0] cpu_wdata,
    output reg [7:0] cpu_rdata,

    // VGA Interface
    input wire [12:0] vga_addr,
    output reg [7:0] vga_rdata
);

    (* ramstyle = "M9K" *)
    reg [7:0] vram [0:8191];


    // =========================================================
    // CPU PORT
    // =========================================================

    always @(posedge clk) begin

        if (cpu_we) begin
            vram[cpu_addr] <= cpu_wdata;
        end

        cpu_rdata <= vram[cpu_addr];

    end


    // =========================================================
    // VGA PORT
    // =========================================================

    always @(posedge clk) begin

        vga_rdata <= vram[vga_addr];

    end


endmodule