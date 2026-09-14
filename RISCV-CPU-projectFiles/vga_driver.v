module vga_driver (
    input wire clk_50mhz,
    input wire rst,
    output reg hsync,
    output reg vsync,
    output wire [9:0] pixel_x,
    output wire [9:0] pixel_y,
    output wire video_on
);
    // 25MHz Clock Enable (Instead of a generated clock)
    reg clk_en;
	always @(posedge clk_50mhz or posedge rst) begin
		 if (rst) clk_en <= 1'b0;
		 else clk_en <= ~clk_en;
	end

    localparam H_ACTIVE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48, H_TOTAL = 800;
    localparam V_ACTIVE = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33, V_TOTAL = 525;

    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    // Everything now runs smoothly on the main 50MHz clock
    always @(posedge clk_50mhz or posedge rst) begin
        if (rst) begin
            h_cnt <= 10'd0;
            v_cnt <= 10'd0;
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else if (clk_en) begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 10'd0;
                if (v_cnt == V_TOTAL - 1)
                    v_cnt <= 10'd0;
                else
                    v_cnt <= v_cnt + 10'd1;
            end else begin
                h_cnt <= h_cnt + 10'd1;
            end
            
            hsync <= ~(h_cnt >= (H_ACTIVE + H_FP) && h_cnt < (H_ACTIVE + H_FP + H_SYNC));
            vsync <= ~(v_cnt >= (V_ACTIVE + V_FP) && v_cnt < (V_ACTIVE + V_FP + V_SYNC));
        end
    end

    assign pixel_x = h_cnt;
    assign pixel_y = v_cnt;
    assign video_on = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);
endmodule