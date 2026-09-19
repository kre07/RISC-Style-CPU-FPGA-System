module vga_driver (

    // PART 1: Inputs / Outputs
    input wire clk_50mhz, // 50 MHz clock from FPGA
    input wire rst,       // Reset VGA back to starting position

    output reg hsync, // Horizontal sync signal
    output reg vsync, // Vertical sync signal

    output wire [9:0] pixel_x, // Current horizontal pixel position
    output wire [9:0] pixel_y, // Current vertical pixel position

    output wire video_on // 1 when inside visible 640x480 screen
);


    // --------------------------------------------------
    // PART 2: VGA TIMING VALUES
    // --------------------------------------------------

    localparam H_ACTIVE = 640; // Visible horizontal pixels
    localparam H_FP     = 16;  // Horizontal front porch
    localparam H_SYNC   = 96;  // Horizontal sync period
    localparam H_BP     = 48;  // Horizontal back porch
    localparam H_TOTAL  = 800; // Total horizontal positions

    localparam V_ACTIVE = 480; // Visible vertical rows
    localparam V_FP     = 10;  // Vertical front porch
    localparam V_SYNC   = 2;   // Vertical sync period
    localparam V_BP     = 33;  // Vertical back porch
    localparam V_TOTAL  = 525; // Total vertical rows


    // --------------------------------------------------
    // PART 3: CLOCK ENABLE
    // --------------------------------------------------

    reg clk_en;
    // Used to make VGA position update every other 50 MHz cycle
    // Gives approximately a 25 MHz pixel rate


    // --------------------------------------------------
    // PART 4: SCREEN POSITION COUNTERS
    // --------------------------------------------------

    reg [9:0] h_cnt;
    // Horizontal position
    // Moves from left to right

    reg [9:0] v_cnt;
    // Vertical position
    // Moves from top to bottom


    // --------------------------------------------------
    // PART 5: DIVIDE VGA UPDATE RATE BY 2
    // --------------------------------------------------

    always @(posedge clk_50mhz or posedge rst) begin

        if (rst)
            clk_en <= 1'b0;

        else
            clk_en <= ~clk_en;
            // Flip:
            // 0 -> 1 -> 0 -> 1...
            //
            // 50 MHz / 2 ≈ 25 MHz

    end


    // --------------------------------------------------
    // PART 6: SCREEN SCANNING
    // --------------------------------------------------

    always @(posedge clk_50mhz or posedge rst) begin

        if (rst) begin

            h_cnt <= 10'd0;
            // Reset horizontal position to 0

            v_cnt <= 10'd0;
            // Reset vertical position to 0

            hsync <= 1'b1;
            vsync <= 1'b1;
            // Default sync signals high

        end

        else if (clk_en) begin
        // Only move to next VGA position when clk_en = 1


            // ------------------------------------------
            // PART 7: HORIZONTAL MOVEMENT
            // ------------------------------------------

            if (h_cnt == H_TOTAL - 1) begin

                // Last horizontal position reached
                // H_TOTAL = 800, so last = 799

                h_cnt <= 10'd0;
                // Return to left side


                // --------------------------------------
                // PART 8: VERTICAL MOVEMENT
                // --------------------------------------

                if (v_cnt == V_TOTAL - 1)

                    // Last vertical row reached
                    // V_TOTAL = 525, so last = 524

                    v_cnt <= 10'd0;
                    // Return to top

                else

                    v_cnt <= v_cnt + 10'd1;
                    // Move down one row

            end

            else begin

                h_cnt <= h_cnt + 10'd1;
                // Move one position to the right

            end


            // ------------------------------------------
            // PART 9: HORIZONTAL SYNC
            // ------------------------------------------

            hsync <= ~(h_cnt >= (H_ACTIVE + H_FP) &&
                       h_cnt <  (H_ACTIVE + H_FP + H_SYNC));

            // Horizontal synchronization pulse
            //
            // During horizontal sync region:
            // hsync = 0
            //
            // Otherwise:
            // hsync = 1


            // ------------------------------------------
            // PART 10: VERTICAL SYNC
            // ------------------------------------------

            vsync <= ~(v_cnt >= (V_ACTIVE + V_FP) &&
                       v_cnt <  (V_ACTIVE + V_FP + V_SYNC));

            // Vertical synchronization pulse
            //
            // During vertical sync region:
            // vsync = 0
            //
            // Otherwise:
            // vsync = 1

        end
    end


    // --------------------------------------------------
    // PART 11: OUTPUT CURRENT PIXEL POSITION
    // --------------------------------------------------

    assign pixel_x = h_cnt;
    // Current X coordinate

    assign pixel_y = v_cnt;
    // Current Y coordinate


    // --------------------------------------------------
    // PART 12: CHECK IF PIXEL IS VISIBLE
    // --------------------------------------------------

    assign video_on = (h_cnt < H_ACTIVE) &&
                      (v_cnt < V_ACTIVE);

    // video_on = 1 when:
    //
    // X is 0-639
    // AND
    // Y is 0-479
    //
    // That means we are inside the visible 640x480 screen


endmodule
