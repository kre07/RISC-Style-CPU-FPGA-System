module soc_top (
    input wire CLOCK_50,
    input wire [1:0] KEY,

    output wire [3:0] VGA_R,
    output wire [3:0] VGA_G,
    output wire [3:0] VGA_B,

    output wire VGA_HS,
    output wire VGA_VS,

    output wire [9:0] LEDR
);

    // =========================================================
    // POWER-ON RESET
    // =========================================================
    // Both DE10-Lite pushbuttons are now gameplay controls, so
    // the FPGA automatically holds the CPU in reset briefly after
    // programming/power-up.

    reg [7:0] por_count;

    initial begin
        por_count = 8'd0;
    end

    always @(posedge CLOCK_50) begin
        if (por_count != 8'hFF)
            por_count <= por_count + 8'd1;
    end

    wire rst = (por_count != 8'hFF);


    // =========================================================
    // CPU CLOCK: 50 MHz / 8 = 6.25 MHz
    // =========================================================

    reg [2:0] cpu_clk_div;

    always @(posedge CLOCK_50 or posedge rst) begin
        if (rst)
            cpu_clk_div <= 3'b000;
        else
            cpu_clk_div <= cpu_clk_div + 3'b001;
    end

    wire cpu_clk = cpu_clk_div[2];


    // =========================================================
    // CPU
    // =========================================================

    wire [31:0] pc;
    wire [31:0] instr;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [31:0] mem_rdata;
    wire mem_read;
    wire mem_write;
    wire [3:0] mem_byte_en;

    cpu_core cpu (
        .clk(cpu_clk),
        .rst(rst),
        .instr(instr),
        .mem_rdata(mem_rdata),
        .pc_out(pc),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_byte_en(mem_byte_en)
    );


    // =========================================================
    // BUS DECODER
    // =========================================================

    wire cs_bram;
    wire cs_vga;
    wire cs_gpio;

    bus_decoder bus (
        .addr(mem_addr),
        .cs_bram(cs_bram),
        .cs_vga(cs_vga),
        .cs_gpio(cs_gpio)
    );


    // =========================================================
    // INSTRUCTION / DATA MEMORY
    // =========================================================

    wire [31:0] bram_rdata;

    bram main_memory (
        .clk(~CLOCK_50),
        .addr_a(pc[12:2]),
        .rdata_a(instr),
        .addr_b(mem_addr[12:2]),
        .wdata_b(mem_wdata),
        .we_b(mem_write & cs_bram),
        .rdata_b(bram_rdata)
    );


    // =========================================================
    // BUTTONS / GPIO
    // =========================================================
    // Both buttons now move the basket at the same fast-but-
    // controllable speed:
    //
    // KEY[1] = move RIGHT
    // KEY[0] = move LEFT
    // no button = stop
    // both buttons = stop
    //
    // On the intro screen, either button starts the game.

    wire right_pressed = ~KEY[1];
    wire left_pressed  = ~KEY[0];

    // bit 0 = RIGHT button, bit 1 = LEFT button
    wire [1:0] gpio_buttons = {left_pressed, right_pressed};

    assign mem_rdata =
        cs_bram ? bram_rdata :
        cs_gpio ? {30'd0, gpio_buttons} :
        32'd0;


    // =========================================================
    // GAME STATUS REGISTERS
    // =========================================================
    // CPU writes game state here:
    //
    // 0x80004000 score (0..99)
    // 0x80004004 lives (0..3)
    // 0x80004008 state (0=intro, 1=playing)
    // 0x8000400C basket X
    // 0x80004010 fruit 1 X
    // 0x80004014 fruit 1 Y
    // 0x80004018 fruit 2 X
    // 0x8000401C fruit 2 Y
    // 0x80004020 fruit 3 X
    // 0x80004024 fruit 3 Y

    reg [6:0] score_reg;
    reg [1:0] lives_reg;
    reg       game_state_reg;
    reg [6:0] basket_x_reg;
    reg [6:0] fruit1_x_reg;
    reg [6:0] fruit1_y_reg;
    reg [6:0] fruit2_x_reg;
    reg [6:0] fruit2_y_reg;
    reg [6:0] fruit3_x_reg;
    reg [6:0] fruit3_y_reg;

    always @(posedge cpu_clk or posedge rst) begin
        if (rst) begin
            score_reg      <= 7'd0;
            lives_reg      <= 2'd3;
            game_state_reg <= 1'b0;
            basket_x_reg   <= 7'd35;
            fruit1_x_reg   <= 7'd10;
            fruit1_y_reg   <= 7'd8;
            fruit2_x_reg   <= 7'd36;
            fruit2_y_reg   <= 7'd23;
            fruit3_x_reg   <= 7'd62;
            fruit3_y_reg   <= 7'd38;
        end
        else if (mem_write) begin
            case (mem_addr)
                32'h80004000: score_reg      <= mem_wdata[6:0];
                32'h80004004: lives_reg      <= mem_wdata[1:0];
                32'h80004008: game_state_reg <= mem_wdata[0];
                32'h8000400C: basket_x_reg   <= mem_wdata[6:0];
                32'h80004010: fruit1_x_reg   <= mem_wdata[6:0];
                32'h80004014: fruit1_y_reg   <= mem_wdata[6:0];
                32'h80004018: fruit2_x_reg   <= mem_wdata[6:0];
                32'h8000401C: fruit2_y_reg   <= mem_wdata[6:0];
                32'h80004020: fruit3_x_reg   <= mem_wdata[6:0];
                32'h80004024: fruit3_y_reg   <= mem_wdata[6:0];
                default: ;
            endcase
        end
    end


    // =========================================================
    // CLOCK-DOMAIN SYNC FOR VGA
    // =========================================================

    reg [58:0] game_sync1;
    reg [58:0] game_sync2;

    always @(posedge CLOCK_50 or posedge rst) begin
        if (rst) begin
            game_sync1 <= {
                7'd0, 2'd3, 1'b0, 7'd35,
                7'd10, 7'd8,
                7'd36, 7'd23,
                7'd62, 7'd38
            };
            game_sync2 <= {
                7'd0, 2'd3, 1'b0, 7'd35,
                7'd10, 7'd8,
                7'd36, 7'd23,
                7'd62, 7'd38
            };
        end
        else begin
            game_sync1 <= {
                score_reg,
                lives_reg,
                game_state_reg,
                basket_x_reg,
                fruit1_x_reg,
                fruit1_y_reg,
                fruit2_x_reg,
                fruit2_y_reg,
                fruit3_x_reg,
                fruit3_y_reg
            };
            game_sync2 <= game_sync1;
        end
    end

    wire [6:0] score_vga      = game_sync2[58:52];
    wire [1:0] lives_vga      = game_sync2[51:50];
    wire       game_state_vga = game_sync2[49];
    wire [6:0] basket_x_vga   = game_sync2[48:42];
    wire [6:0] fruit1_x_vga   = game_sync2[41:35];
    wire [6:0] fruit1_y_vga   = game_sync2[34:28];
    wire [6:0] fruit2_x_vga   = game_sync2[27:21];
    wire [6:0] fruit2_y_vga   = game_sync2[20:14];
    wire [6:0] fruit3_x_vga   = game_sync2[13:7];
    wire [6:0] fruit3_y_vga   = game_sync2[6:0];


    // =========================================================
    // VGA TIMING
    // =========================================================

    wire hsync;
    wire vsync;
    wire video_on;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;

    vga_driver display (
        .clk_50mhz(CLOCK_50),
        .rst(rst),
        .hsync(hsync),
        .vsync(vsync),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .video_on(video_on)
    );

    assign VGA_HS = hsync;
    assign VGA_VS = vsync;

    // logical 80 x 60 cells; each cell = 8 x 8 VGA pixels
    wire [6:0] cell_x = pixel_x[9:3];
    wire [6:0] cell_y = pixel_y[9:3];


    // =========================================================
    // 5 x 7 FONT
    // =========================================================

    function glyph_bit;
        input [7:0] ch;
        input [2:0] rr;
        input [2:0] cc;
        reg [4:0] bits;
        begin
            bits = 5'b00000;

            case (ch)
                8'h41: begin // A
                    case (rr)
                        0: bits = 5'b01110; 1: bits = 5'b10001;
                        2: bits = 5'b10001; 3: bits = 5'b11111;
                        4: bits = 5'b10001; 5: bits = 5'b10001;
                        6: bits = 5'b10001;
                    endcase
                end

                8'h42: begin // B
                    case (rr)
                        0: bits = 5'b11110; 1: bits = 5'b10001;
                        2: bits = 5'b10001; 3: bits = 5'b11110;
                        4: bits = 5'b10001; 5: bits = 5'b10001;
                        6: bits = 5'b11110;
                    endcase
                end

                8'h43: begin // C
                    case (rr)
                        0: bits = 5'b11111; 1: bits = 5'b10000;
                        2: bits = 5'b10000; 3: bits = 5'b10000;
                        4: bits = 5'b10000; 5: bits = 5'b10000;
                        6: bits = 5'b11111;
                    endcase
                end

                8'h45: begin // E
                    case (rr)
                        0: bits = 5'b11111; 1: bits = 5'b10000;
                        2: bits = 5'b10000; 3: bits = 5'b11110;
                        4: bits = 5'b10000; 5: bits = 5'b10000;
                        6: bits = 5'b11111;
                    endcase
                end

                8'h46: begin // F
                    case (rr)
                        0: bits = 5'b11111; 1: bits = 5'b10000;
                        2: bits = 5'b10000; 3: bits = 5'b11110;
                        4: bits = 5'b10000; 5: bits = 5'b10000;
                        6: bits = 5'b10000;
                    endcase
                end

                8'h48: begin // H
                    case (rr)
                        0: bits = 5'b10001; 1: bits = 5'b10001;
                        2: bits = 5'b10001; 3: bits = 5'b11111;
                        4: bits = 5'b10001; 5: bits = 5'b10001;
                        6: bits = 5'b10001;
                    endcase
                end

                8'h49: begin // I
                    case (rr)
                        0: bits = 5'b11111; 1: bits = 5'b00100;
                        2: bits = 5'b00100; 3: bits = 5'b00100;
                        4: bits = 5'b00100; 5: bits = 5'b00100;
                        6: bits = 5'b11111;
                    endcase
                end

                8'h4F: begin // O
                    case (rr)
                        0: bits = 5'b01110; 1: bits = 5'b10001;
                        2: bits = 5'b10001; 3: bits = 5'b10001;
                        4: bits = 5'b10001; 5: bits = 5'b10001;
                        6: bits = 5'b01110;
                    endcase
                end

                8'h50: begin // P
                    case (rr)
                        0: bits = 5'b11110; 1: bits = 5'b10001;
                        2: bits = 5'b10001; 3: bits = 5'b11110;
                        4: bits = 5'b10000; 5: bits = 5'b10000;
                        6: bits = 5'b10000;
                    endcase
                end

                8'h52: begin // R
                    case (rr)
                        0: bits = 5'b11110; 1: bits = 5'b10001;
                        2: bits = 5'b10001; 3: bits = 5'b11110;
                        4: bits = 5'b10100; 5: bits = 5'b10010;
                        6: bits = 5'b10001;
                    endcase
                end

                8'h53: begin // S
                    case (rr)
                        0: bits = 5'b11111; 1: bits = 5'b10000;
                        2: bits = 5'b10000; 3: bits = 5'b11111;
                        4: bits = 5'b00001; 5: bits = 5'b00001;
                        6: bits = 5'b11111;
                    endcase
                end

                8'h54: begin // T
                    case (rr)
                        0: bits = 5'b11111; 1: bits = 5'b00100;
                        2: bits = 5'b00100; 3: bits = 5'b00100;
                        4: bits = 5'b00100; 5: bits = 5'b00100;
                        6: bits = 5'b00100;
                    endcase
                end

                8'h55: begin // U
                    case (rr)
                        0: bits = 5'b10001; 1: bits = 5'b10001;
                        2: bits = 5'b10001; 3: bits = 5'b10001;
                        4: bits = 5'b10001; 5: bits = 5'b10001;
                        6: bits = 5'b11111;
                    endcase
                end

                default: bits = 5'b00000;
            endcase

            if (cc < 3'd5)
                glyph_bit = bits[4-cc];
            else
                glyph_bit = 1'b0;
        end
    endfunction


    // =========================================================
    // INTRO: FRUIT CATCHER
    // =========================================================

    wire intro_title_y = (cell_y >= 7'd9) && (cell_y <= 7'd15);
    wire [2:0] intro_title_row = cell_y - 7'd9;

    wire intro_fruit_text = intro_title_y && (
        ((cell_x >= 7'd1)  && (cell_x <= 7'd5)  && glyph_bit(8'h46, intro_title_row, cell_x - 7'd1 )) ||
        ((cell_x >= 7'd7)  && (cell_x <= 7'd11) && glyph_bit(8'h52, intro_title_row, cell_x - 7'd7 )) ||
        ((cell_x >= 7'd13) && (cell_x <= 7'd17) && glyph_bit(8'h55, intro_title_row, cell_x - 7'd13)) ||
        ((cell_x >= 7'd19) && (cell_x <= 7'd23) && glyph_bit(8'h49, intro_title_row, cell_x - 7'd19)) ||
        ((cell_x >= 7'd25) && (cell_x <= 7'd29) && glyph_bit(8'h54, intro_title_row, cell_x - 7'd25))
    );

    wire intro_catcher_text = intro_title_y && (
        ((cell_x >= 7'd37) && (cell_x <= 7'd41) && glyph_bit(8'h43, intro_title_row, cell_x - 7'd37)) ||
        ((cell_x >= 7'd43) && (cell_x <= 7'd47) && glyph_bit(8'h41, intro_title_row, cell_x - 7'd43)) ||
        ((cell_x >= 7'd49) && (cell_x <= 7'd53) && glyph_bit(8'h54, intro_title_row, cell_x - 7'd49)) ||
        ((cell_x >= 7'd55) && (cell_x <= 7'd59) && glyph_bit(8'h43, intro_title_row, cell_x - 7'd55)) ||
        ((cell_x >= 7'd61) && (cell_x <= 7'd65) && glyph_bit(8'h48, intro_title_row, cell_x - 7'd61)) ||
        ((cell_x >= 7'd67) && (cell_x <= 7'd71) && glyph_bit(8'h45, intro_title_row, cell_x - 7'd67)) ||
        ((cell_x >= 7'd73) && (cell_x <= 7'd77) && glyph_bit(8'h52, intro_title_row, cell_x - 7'd73))
    );


    // =========================================================
    // INTRO: PRESS START
    // =========================================================

    wire intro_prompt_y = (cell_y >= 7'd38) && (cell_y <= 7'd44);
    wire [2:0] intro_prompt_row = cell_y - 7'd38;

    wire intro_prompt_pixel = intro_prompt_y && (
        ((cell_x >= 7'd8)  && (cell_x <= 7'd12) && glyph_bit(8'h50, intro_prompt_row, cell_x - 7'd8 )) ||
        ((cell_x >= 7'd14) && (cell_x <= 7'd18) && glyph_bit(8'h52, intro_prompt_row, cell_x - 7'd14)) ||
        ((cell_x >= 7'd20) && (cell_x <= 7'd24) && glyph_bit(8'h45, intro_prompt_row, cell_x - 7'd20)) ||
        ((cell_x >= 7'd26) && (cell_x <= 7'd30) && glyph_bit(8'h53, intro_prompt_row, cell_x - 7'd26)) ||
        ((cell_x >= 7'd32) && (cell_x <= 7'd36) && glyph_bit(8'h53, intro_prompt_row, cell_x - 7'd32)) ||
        ((cell_x >= 7'd44) && (cell_x <= 7'd48) && glyph_bit(8'h53, intro_prompt_row, cell_x - 7'd44)) ||
        ((cell_x >= 7'd50) && (cell_x <= 7'd54) && glyph_bit(8'h54, intro_prompt_row, cell_x - 7'd50)) ||
        ((cell_x >= 7'd56) && (cell_x <= 7'd60) && glyph_bit(8'h41, intro_prompt_row, cell_x - 7'd56)) ||
        ((cell_x >= 7'd62) && (cell_x <= 7'd66) && glyph_bit(8'h52, intro_prompt_row, cell_x - 7'd62)) ||
        ((cell_x >= 7'd68) && (cell_x <= 7'd72) && glyph_bit(8'h54, intro_prompt_row, cell_x - 7'd68))
    );


    // =========================================================
    // HUD: SCORE
    // =========================================================

    wire hud_text_y = (cell_y >= 7'd1) && (cell_y <= 7'd7);
    wire [2:0] hud_row = cell_y - 7'd1;

    wire hud_score_text = hud_text_y && (
        ((cell_x >= 7'd2)  && (cell_x <= 7'd6)  && glyph_bit(8'h53, hud_row, cell_x - 7'd2 )) ||
        ((cell_x >= 7'd8)  && (cell_x <= 7'd12) && glyph_bit(8'h43, hud_row, cell_x - 7'd8 )) ||
        ((cell_x >= 7'd14) && (cell_x <= 7'd18) && glyph_bit(8'h4F, hud_row, cell_x - 7'd14)) ||
        ((cell_x >= 7'd20) && (cell_x <= 7'd24) && glyph_bit(8'h52, hud_row, cell_x - 7'd20)) ||
        ((cell_x >= 7'd26) && (cell_x <= 7'd30) && glyph_bit(8'h45, hud_row, cell_x - 7'd26))
    );

    // TURBO label appears while KEY0 is held.
    wire hud_turbo_text = hud_text_y && (left_pressed || right_pressed) && (
        ((cell_x >= 7'd36) && (cell_x <= 7'd40) && glyph_bit(8'h54, hud_row, cell_x - 7'd36)) ||
        ((cell_x >= 7'd42) && (cell_x <= 7'd46) && glyph_bit(8'h55, hud_row, cell_x - 7'd42)) ||
        ((cell_x >= 7'd48) && (cell_x <= 7'd52) && glyph_bit(8'h52, hud_row, cell_x - 7'd48)) ||
        ((cell_x >= 7'd54) && (cell_x <= 7'd58) && glyph_bit(8'h42, hud_row, cell_x - 7'd54)) ||
        ((cell_x >= 7'd60) && (cell_x <= 7'd64) && glyph_bit(8'h4F, hud_row, cell_x - 7'd60))
    );


    // =========================================================
    // SCORE DIGITS 00..99
    // =========================================================

    function [6:0] digit_segments;
        input [3:0] digit;
        begin
            case (digit)
                4'd0: digit_segments = 7'b1111110;
                4'd1: digit_segments = 7'b0110000;
                4'd2: digit_segments = 7'b1101101;
                4'd3: digit_segments = 7'b1111001;
                4'd4: digit_segments = 7'b0110011;
                4'd5: digit_segments = 7'b1011011;
                4'd6: digit_segments = 7'b1011111;
                4'd7: digit_segments = 7'b1110000;
                4'd8: digit_segments = 7'b1111111;
                4'd9: digit_segments = 7'b1111011;
                default: digit_segments = 7'b0000000;
            endcase
        end
    endfunction

    function digit_pixel;
        input [3:0] digit;
        input [5:0] dx;
        input [5:0] dy;
        reg [6:0] seg;
        begin
            seg = digit_segments(digit);
            digit_pixel =
                (seg[6] && (dx >= 6'd4)  && (dx < 6'd24) && (dy < 6'd4)) ||
                (seg[5] && (dx >= 6'd22) && (dx < 6'd26) && (dy >= 6'd4)  && (dy < 6'd22)) ||
                (seg[4] && (dx >= 6'd22) && (dx < 6'd26) && (dy >= 6'd24) && (dy < 6'd42)) ||
                (seg[3] && (dx >= 6'd4)  && (dx < 6'd24) && (dy >= 6'd42) && (dy < 6'd46)) ||
                (seg[2] && (dx < 6'd4)   && (dy >= 6'd24) && (dy < 6'd42)) ||
                (seg[1] && (dx < 6'd4)   && (dy >= 6'd4)  && (dy < 6'd22)) ||
                (seg[0] && (dx >= 6'd4)  && (dx < 6'd24) && (dy >= 6'd21) && (dy < 6'd25));
        end
    endfunction

    wire [3:0] score_tens = score_vga / 7'd10;
    wire [3:0] score_ones = score_vga % 7'd10;

    wire tens_box = (pixel_x >= 10'd270) && (pixel_x < 10'd296) &&
                    (pixel_y >= 10'd9) && (pixel_y < 10'd55);
    wire ones_box = (pixel_x >= 10'd304) && (pixel_x < 10'd330) &&
                    (pixel_y >= 10'd9) && (pixel_y < 10'd55);

    wire tens_pixel = tens_box && digit_pixel(
        score_tens,
        pixel_x - 10'd270,
        pixel_y - 10'd9
    );

    wire ones_pixel = ones_box && digit_pixel(
        score_ones,
        pixel_x - 10'd304,
        pixel_y - 10'd9
    );

    wire score_digit_pixel = tens_pixel | ones_pixel;


    // =========================================================
    // HEARTS / LIVES
    // =========================================================

    function heart_pixel;
        input [4:0] dx;
        input [4:0] dy;
        begin
            heart_pixel = 1'b0;
            if (dy <= 5'd3)
                heart_pixel = ((dx >= 5'd3) && (dx <= 5'd8)) ||
                              ((dx >= 5'd15) && (dx <= 5'd20));
            else if (dy <= 5'd9)
                heart_pixel = (dx >= 5'd1) && (dx <= 5'd22);
            else if (dy <= 5'd12)
                heart_pixel = (dx >= 5'd3) && (dx <= 5'd20);
            else if (dy <= 5'd15)
                heart_pixel = (dx >= 5'd6) && (dx <= 5'd17);
            else if (dy <= 5'd17)
                heart_pixel = (dx >= 5'd9) && (dx <= 5'd14);
            else if (dy <= 5'd19)
                heart_pixel = (dx >= 5'd11) && (dx <= 5'd12);
        end
    endfunction

    wire heart1_shape =
        (pixel_x >= 10'd500) && (pixel_x < 10'd524) &&
        (pixel_y >= 10'd20)  && (pixel_y < 10'd40) &&
        heart_pixel(pixel_x - 10'd500, pixel_y - 10'd20);

    wire heart2_shape =
        (pixel_x >= 10'd540) && (pixel_x < 10'd564) &&
        (pixel_y >= 10'd20)  && (pixel_y < 10'd40) &&
        heart_pixel(pixel_x - 10'd540, pixel_y - 10'd20);

    wire heart3_shape =
        (pixel_x >= 10'd580) && (pixel_x < 10'd604) &&
        (pixel_y >= 10'd20)  && (pixel_y < 10'd40) &&
        heart_pixel(pixel_x - 10'd580, pixel_y - 10'd20);

    wire any_hud_heart = heart1_shape | heart2_shape | heart3_shape;

    wire active_hud_heart =
        (heart1_shape && (lives_vga >= 2'd1)) ||
        (heart2_shape && (lives_vga >= 2'd2)) ||
        (heart3_shape && (lives_vga >= 2'd3));

    wire intro_hearts =
        ((pixel_x >= 10'd260) && (pixel_x < 10'd284) &&
         (pixel_y >= 10'd390) && (pixel_y < 10'd410) &&
         heart_pixel(pixel_x - 10'd260, pixel_y - 10'd390)) ||
        ((pixel_x >= 10'd308) && (pixel_x < 10'd332) &&
         (pixel_y >= 10'd390) && (pixel_y < 10'd410) &&
         heart_pixel(pixel_x - 10'd308, pixel_y - 10'd390)) ||
        ((pixel_x >= 10'd356) && (pixel_x < 10'd380) &&
         (pixel_y >= 10'd390) && (pixel_y < 10'd410) &&
         heart_pixel(pixel_x - 10'd356, pixel_y - 10'd390));


    // =========================================================
    // INTRO APPLE
    // =========================================================

    wire intro_apple_box =
        (pixel_x >= 10'd288) && (pixel_x < 10'd352) &&
        (pixel_y >= 10'd185) && (pixel_y < 10'd249);

    wire [6:0] intro_ax = pixel_x - 10'd288;
    wire [6:0] intro_ay = pixel_y - 10'd185;

    wire intro_apple_body = intro_apple_box && (
        ((intro_ay >= 7'd16) && (intro_ay <= 7'd23) && (intro_ax >= 7'd12) && (intro_ax <= 7'd51)) ||
        ((intro_ay >= 7'd24) && (intro_ay <= 7'd47) && (intro_ax >= 7'd4)  && (intro_ax <= 7'd59)) ||
        ((intro_ay >= 7'd48) && (intro_ay <= 7'd55) && (intro_ax >= 7'd12) && (intro_ax <= 7'd51)) ||
        ((intro_ay >= 7'd56) && (intro_ay <= 7'd59) && (intro_ax >= 7'd20) && (intro_ax <= 7'd43))
    );

    wire intro_apple_leaf = intro_apple_box && (
        ((intro_ay >= 7'd2) && (intro_ay <= 7'd15) && (intro_ax >= 7'd31) && (intro_ax <= 7'd38)) ||
        ((intro_ay >= 7'd7) && (intro_ay <= 7'd15) && (intro_ax >= 7'd39) && (intro_ax <= 7'd51))
    );

    wire intro_apple_shine = intro_apple_body &&
                             (intro_ax >= 7'd15) && (intro_ax <= 7'd21) &&
                             (intro_ay >= 7'd27) && (intro_ay <= 7'd36);


    // =========================================================
    // FRUIT SPRITE FUNCTIONS
    // =========================================================

    function fruit_body_pixel;
        input [3:0] dx;
        input [3:0] dy;
        begin
            fruit_body_pixel =
                ((dy >= 4'd3)  && (dy <= 4'd4)  && (dx >= 4'd4) && (dx <= 4'd11)) ||
                ((dy >= 4'd5)  && (dy <= 4'd6)  && (dx >= 4'd2) && (dx <= 4'd13)) ||
                ((dy >= 4'd7)  && (dy <= 4'd11) && (dx >= 4'd1) && (dx <= 4'd14)) ||
                ((dy >= 4'd12) && (dy <= 4'd13) && (dx >= 4'd2) && (dx <= 4'd13)) ||
                ((dy >= 4'd14) && (dy <= 4'd15) && (dx >= 4'd4) && (dx <= 4'd11));
        end
    endfunction

    function fruit_leaf_pixel;
        input [3:0] dx;
        input [3:0] dy;
        begin
            fruit_leaf_pixel =
                ((dy <= 4'd2) && (dx >= 4'd8) && (dx <= 4'd10)) ||
                ((dy >= 4'd1) && (dy <= 4'd3) && (dx >= 4'd10) && (dx <= 4'd12));
        end
    endfunction

    function fruit_shine_pixel;
        input [3:0] dx;
        input [3:0] dy;
        begin
            fruit_shine_pixel = fruit_body_pixel(dx, dy) &&
                                (dx >= 4'd4) && (dx <= 4'd5) &&
                                (dy >= 4'd6) && (dy <= 4'd8);
        end
    endfunction


    // =========================================================
    // THREE FALLING FRUITS
    // =========================================================

    wire [9:0] fruit1_x_pix = {fruit1_x_vga, 3'b000};
    wire [9:0] fruit1_y_pix = {fruit1_y_vga, 3'b000};
    wire [9:0] fruit2_x_pix = {fruit2_x_vga, 3'b000};
    wire [9:0] fruit2_y_pix = {fruit2_y_vga, 3'b000};
    wire [9:0] fruit3_x_pix = {fruit3_x_vga, 3'b000};
    wire [9:0] fruit3_y_pix = {fruit3_y_vga, 3'b000};

    wire fruit1_box =
        (pixel_x >= fruit1_x_pix) && (pixel_x < fruit1_x_pix + 10'd16) &&
        (pixel_y >= fruit1_y_pix) && (pixel_y < fruit1_y_pix + 10'd16);

    wire fruit2_box =
        (pixel_x >= fruit2_x_pix) && (pixel_x < fruit2_x_pix + 10'd16) &&
        (pixel_y >= fruit2_y_pix) && (pixel_y < fruit2_y_pix + 10'd16);

    wire fruit3_box =
        (pixel_x >= fruit3_x_pix) && (pixel_x < fruit3_x_pix + 10'd16) &&
        (pixel_y >= fruit3_y_pix) && (pixel_y < fruit3_y_pix + 10'd16);

    wire [3:0] fruit1_dx = pixel_x - fruit1_x_pix;
    wire [3:0] fruit1_dy = pixel_y - fruit1_y_pix;
    wire [3:0] fruit2_dx = pixel_x - fruit2_x_pix;
    wire [3:0] fruit2_dy = pixel_y - fruit2_y_pix;
    wire [3:0] fruit3_dx = pixel_x - fruit3_x_pix;
    wire [3:0] fruit3_dy = pixel_y - fruit3_y_pix;

    wire fruit1_body = fruit1_box && fruit_body_pixel(fruit1_dx, fruit1_dy);
    wire fruit1_leaf = fruit1_box && fruit_leaf_pixel(fruit1_dx, fruit1_dy);
    wire fruit1_shine = fruit1_box && fruit_shine_pixel(fruit1_dx, fruit1_dy);

    wire fruit2_body = fruit2_box && fruit_body_pixel(fruit2_dx, fruit2_dy);
    wire fruit2_leaf = fruit2_box && fruit_leaf_pixel(fruit2_dx, fruit2_dy);
    wire fruit2_shine = fruit2_box && fruit_shine_pixel(fruit2_dx, fruit2_dy);

    wire fruit3_body = fruit3_box && fruit_body_pixel(fruit3_dx, fruit3_dy);
    wire fruit3_leaf = fruit3_box && fruit_leaf_pixel(fruit3_dx, fruit3_dy);
    wire fruit3_shine = fruit3_box && fruit_shine_pixel(fruit3_dx, fruit3_dy);


    // =========================================================
    // BIGGER BASKET SPRITE
    // =========================================================
    // 12 logical cells wide (96 VGA pixels).  The body narrows
    // toward the bottom and the arch above it makes it read as a
    // real basket instead of a plain rectangle.

    wire [9:0] basket_x_pix = {basket_x_vga, 3'b000};

    // Handle: upside-down U above the rim.
    wire basket_handle_top =
        (pixel_x >= basket_x_pix + 10'd20) &&
        (pixel_x <  basket_x_pix + 10'd76) &&
        (pixel_y >= 10'd428) &&
        (pixel_y <  10'd432);

    wire basket_handle_left =
        (pixel_x >= basket_x_pix + 10'd16) &&
        (pixel_x <  basket_x_pix + 10'd20) &&
        (pixel_y >= 10'd432) &&
        (pixel_y <  10'd448);

    wire basket_handle_right =
        (pixel_x >= basket_x_pix + 10'd76) &&
        (pixel_x <  basket_x_pix + 10'd80) &&
        (pixel_y >= 10'd432) &&
        (pixel_y <  10'd448);

    wire basket_handle =
        basket_handle_top |
        basket_handle_left |
        basket_handle_right;

    // Wide lip/rim where the fruit is caught.
    wire basket_rim =
        (pixel_x >= basket_x_pix) &&
        (pixel_x < basket_x_pix + 10'd96) &&
        (pixel_y >= 10'd448) &&
        (pixel_y < 10'd456);

    // Tapered woven body.
    wire basket_upper =
        (pixel_x >= basket_x_pix + 10'd8) &&
        (pixel_x < basket_x_pix + 10'd88) &&
        (pixel_y >= 10'd456) &&
        (pixel_y < 10'd464);

    wire basket_mid =
        (pixel_x >= basket_x_pix + 10'd16) &&
        (pixel_x < basket_x_pix + 10'd80) &&
        (pixel_y >= 10'd464) &&
        (pixel_y < 10'd472);

    wire basket_bottom =
        (pixel_x >= basket_x_pix + 10'd24) &&
        (pixel_x < basket_x_pix + 10'd72) &&
        (pixel_y >= 10'd472) &&
        (pixel_y < 10'd476);

    wire basket_body =
        basket_upper |
        basket_mid |
        basket_bottom;

    wire basket_pixel =
        basket_handle |
        basket_rim |
        basket_body;

    // Cross-hatch pattern only on the body.
    wire basket_weave = basket_body &&
                        ((pixel_x[3:0] == 4'd1) ||
                         (pixel_x[3:0] == 4'd8) ||
                         (pixel_y[2:0] == 3'd3));


    // =========================================================
    // INTRO BLINK COUNTER
    // =========================================================

    reg [24:0] visual_counter;

    always @(posedge CLOCK_50 or posedge rst) begin
        if (rst)
            visual_counter <= 25'd0;
        else
            visual_counter <= visual_counter + 25'd1;
    end


    // =========================================================
    // VGA COLOR GENERATOR
    // =========================================================

    reg [3:0] red;
    reg [3:0] green;
    reg [3:0] blue;

    always @(*) begin
        red   = 4'h0;
        green = 4'h0;
        blue  = 4'h0;

        if (video_on) begin

            // =================================================
            // INTRO SCREEN
            // =================================================
            if (!game_state_vga) begin
                red   = 4'h0;
                green = 4'h0;
                blue  = 4'h2;

                // border
                if ((pixel_x < 10'd5) || (pixel_x >= 10'd635) ||
                    (pixel_y < 10'd5) || (pixel_y >= 10'd475)) begin
                    red   = 4'h0;
                    green = 4'hC;
                    blue  = 4'hF;
                end

                if (intro_fruit_text) begin
                    red   = 4'hF;
                    green = 4'h8;
                    blue  = 4'h1;
                end

                if (intro_catcher_text) begin
                    red   = 4'h2;
                    green = 4'hF;
                    blue  = 4'h8;
                end

                if (intro_apple_body) begin
                    red   = 4'hF;
                    green = 4'h1;
                    blue  = 4'h1;
                end

                if (intro_apple_shine) begin
                    red   = 4'hF;
                    green = 4'hB;
                    blue  = 4'hB;
                end

                if (intro_apple_leaf) begin
                    red   = 4'h1;
                    green = 4'hE;
                    blue  = 4'h2;
                end

                if (intro_prompt_pixel) begin
                    if (visual_counter[24]) begin
                        red   = 4'hF;
                        green = 4'hF;
                        blue  = 4'hF;
                    end
                    else begin
                        red   = 4'hF;
                        green = 4'hD;
                        blue  = 4'h2;
                    end
                end

                if (intro_hearts) begin
                    red   = 4'hF;
                    green = 4'h1;
                    blue  = 4'h3;
                end
            end

            // =================================================
            // GAME SCREEN
            // =================================================
            else begin
                // dark navy field
                red   = 4'h0;
                green = 4'h0;
                blue  = 4'h2;

                // HUD panel
                if (pixel_y < 10'd64) begin
                    red   = 4'h0;
                    green = 4'h2;
                    blue  = 4'h5;
                end

                if (hud_score_text) begin
                    red   = 4'hD;
                    green = 4'hF;
                    blue  = 4'hF;
                end

                if (score_digit_pixel) begin
                    red   = 4'hF;
                    green = 4'hD;
                    blue  = 4'h1;
                end

                // TURBO flashes green while KEY0 is held
                if (hud_turbo_text) begin
                    red   = 4'h2;
                    green = 4'hF;
                    blue  = 4'h4;
                end

                // lives
                if (any_hud_heart) begin
                    if (active_hud_heart) begin
                        red   = 4'hF;
                        green = 4'h1;
                        blue  = 4'h3;
                    end
                    else begin
                        red   = 4'h4;
                        green = 4'h4;
                        blue  = 4'h5;
                    end
                end

                // ground
                if ((pixel_y >= 10'd472) && (pixel_y < 10'd476)) begin
                    red   = 4'h1;
                    green = 4'h8;
                    blue  = 4'h3;
                end

                // basket
                if (basket_pixel) begin
                    if (basket_weave) begin
                        red   = 4'h8;
                        green = 4'h3;
                        blue  = 4'h0;
                    end
                    else if (basket_rim || basket_handle) begin
                        red   = 4'hF;
                        green = 4'hC;
                        blue  = 4'h2;
                    end
                    else begin
                        red   = 4'hD;
                        green = 4'h7;
                        blue  = 4'h1;
                    end
                end

                // FRUIT 1: red apple
                if (fruit1_body) begin
                    red   = 4'hF;
                    green = 4'h1;
                    blue  = 4'h1;
                end
                if (fruit1_shine) begin
                    red   = 4'hF;
                    green = 4'hB;
                    blue  = 4'hB;
                end
                if (fruit1_leaf) begin
                    red   = 4'h1;
                    green = 4'hE;
                    blue  = 4'h2;
                end

                // FRUIT 2: orange/gold fruit
                if (fruit2_body) begin
                    red   = 4'hF;
                    green = 4'h8;
                    blue  = 4'h0;
                end
                if (fruit2_shine) begin
                    red   = 4'hF;
                    green = 4'hE;
                    blue  = 4'h8;
                end
                if (fruit2_leaf) begin
                    red   = 4'h1;
                    green = 4'hE;
                    blue  = 4'h2;
                end

                // FRUIT 3: purple fruit
                if (fruit3_body) begin
                    red   = 4'hB;
                    green = 4'h2;
                    blue  = 4'hF;
                end
                if (fruit3_shine) begin
                    red   = 4'hF;
                    green = 4'hA;
                    blue  = 4'hF;
                end
                if (fruit3_leaf) begin
                    red   = 4'h1;
                    green = 4'hE;
                    blue  = 4'h2;
                end

                // cyan border
                if ((pixel_x < 10'd4) || (pixel_x >= 10'd636) ||
                    (pixel_y < 10'd4) || (pixel_y >= 10'd476)) begin
                    red   = 4'h0;
                    green = 4'hD;
                    blue  = 4'hF;
                end
            end
        end
    end

    assign VGA_R = red;
    assign VGA_G = green;
    assign VGA_B = blue;


    // =========================================================
    // DEBUG LEDs
    // =========================================================
    // LEDR[6:0] = score in binary
    // LEDR[9:7] = remaining lives

    assign LEDR[6:0] = score_reg;
    assign LEDR[9:7] = {
        (lives_reg >= 2'd3),
        (lives_reg >= 2'd2),
        (lives_reg >= 2'd1)
    };

endmodule
