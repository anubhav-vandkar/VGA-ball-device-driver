/*
 * Avalon memory-mapped peripheral that generates VGA
 *
 * Stephen A. Edwards
 * Columbia University
 *
 * Register map:
 * 
 * Byte Offset  7 ... 0   Meaning
 *        0    |  Red  |  Red component of background color (0-255)
 *        1    | Green |  Green component
 *        2    | Blue  |  Blue component
 */

module vga_ball(input logic        clk,
                input logic        reset,
                input logic [7:0]  writedata, // Christian's Claude Notes: We will prob need to update this to 16 bits to fit the 640 x 480 resolution. See section 2.2. We will pass in x,y coordinates.
                input logic        write,
                input logic        chipselect,
                input logic [2:0]  address, // Christian's Claude Notes: We will need to update this to fit the x and y coordinate registers.
                output logic [7:0] VGA_R, VGA_G, VGA_B, 
                output logic       VGA_CLK, VGA_HS, VGA_VS,
                                   VGA_BLANK_n,
                output logic       VGA_SYNC_n);

   logic [10:0]    hcount;
   logic [9:0]     vcount;

   logic [7:0]     background_r, background_g, background_b;

   // Christan's Claude Notes: We will need registers to store x and y coordinates.
        
   vga_counters counters(.clk50(clk), .*);

  // Christian's Claude Notes: Need to update the `always_ff` block to handle writing to the x and y coordinate registers. 
   always_ff @(posedge clk)
     if (reset) begin
        background_r <= 8'h0;
        background_g <= 8'h0;
        background_b <= 8'h80;
     end else if (chipselect && write)
       case (address)
         3'h0 : background_r <= writedata;
         3'h1 : background_g <= writedata;
         3'h2 : background_b <= writedata;
       endcase

   always_comb begin
      {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
      if (VGA_BLANK_n )
        // Christian's Claude Notes: We will need to update the hcount and vcount values to check if we are within the bounds of a ball.
        // Christian's Claude Notes: Look up how we can calculate a ball's shape w/ the equation of a circle.
        // Christian's Claude Notes: Currently, we make a square.   
        if (hcount[10:6] == 5'd3 &&
            vcount[9:5] == 5'd3)
          {VGA_R, VGA_G, VGA_B} = {8'hff, 8'hff, 8'hff};
        else
          {VGA_R, VGA_G, VGA_B} =
             {background_r, background_g, background_b};
   end
               
endmodule

module vga_counters(
 input logic         clk50, reset,
 output logic [10:0] hcount,  // hcount[10:1] is pixel column
 output logic [9:0]  vcount,  // vcount[9:0] is pixel row
 output logic        VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_n, VGA_SYNC_n);

/*
 * 640 X 480 VGA timing for a 50 MHz clock: one pixel every other cycle
 * 
 * HCOUNT 1599 0             1279       1599 0
 *             _______________              ________
 * ___________|    Video      |____________|  Video
 * 
 * 
 * |SYNC| BP |<-- HACTIVE -->|FP|SYNC| BP |<-- HACTIVE
 *       _______________________      _____________
 * |____|       VGA_HS          |____|
 */
   // Parameters for hcount
   parameter HACTIVE      = 11'd 1280,
             HFRONT_PORCH = 11'd 32,
             HSYNC        = 11'd 192,
             HBACK_PORCH  = 11'd 96,   
             HTOTAL       = HACTIVE + HFRONT_PORCH + HSYNC +
                            HBACK_PORCH; // 1600
   
   // Parameters for vcount
   parameter VACTIVE      = 10'd 480,
             VFRONT_PORCH = 10'd 10,
             VSYNC        = 10'd 2,
             VBACK_PORCH  = 10'd 33,
             VTOTAL       = VACTIVE + VFRONT_PORCH + VSYNC +
                            VBACK_PORCH; // 525

   logic endOfLine;
   
   always_ff @(posedge clk50 or posedge reset)
     if (reset)          hcount <= 0;
     else if (endOfLine) hcount <= 0;
     else                hcount <= hcount + 11'd 1;

   assign endOfLine = hcount == HTOTAL - 1;
       
   logic endOfField;
   
   always_ff @(posedge clk50 or posedge reset)
     if (reset)          vcount <= 0;
     else if (endOfLine)
       if (endOfField)   vcount <= 0;
       else              vcount <= vcount + 10'd 1;

   assign endOfField = vcount == VTOTAL - 1;

   // Horizontal sync: from 0x520 to 0x5DF (0x57F)
   // 101 0010 0000 to 101 1101 1111
   assign VGA_HS = !( (hcount[10:8] == 3'b101) &
                      !(hcount[7:5] == 3'b111));
   assign VGA_VS = !( vcount[9:1] == (VACTIVE + VFRONT_PORCH) / 2);

   assign VGA_SYNC_n = 1'b0; // For putting sync on the green signal; unused
   
   // Horizontal active: 0 to 1279     Vertical active: 0 to 479
   // 101 0000 0000  1280              01 1110 0000  480
   // 110 0011 1111  1599              10 0000 1100  524
   assign VGA_BLANK_n = !( hcount[10] & (hcount[9] | hcount[8]) ) &
                        !( vcount[9] | (vcount[8:5] == 4'b1111) );

   /* VGA_CLK is 25 MHz
    *             __    __    __
    * clk50    __|  |__|  |__|
    *        
    *             _____       __
    * hcount[0]__|     |_____|
    */
   assign VGA_CLK = hcount[0]; // 25 MHz clock: rising edge sensitive
   
endmodule


// Extra Christian's Notes:
// "You may observe that your ball “tears” as it moves across the screen. This is caused by
// changing the ball’s coordinates while one of its lines is being generated. To fix this, make
// it so that your ball’s coordinates only change when other lines are being displayed." - Lab 3 Handout.
// 
// ======= Claude Notes =======
//
// Handle the Tearing Problem
// Screen tearing happens when you update the ball's coordinates while the electron beam is currently drawing that part of the screen. Halfway through drawing a frame the ball suddenly jumps, causing a torn appearance.
// The fix conceptually is to have two sets of coordinate registers:

// A buffer register that the processor writes to anytime it wants
// An active register that the drawing logic actually uses

// You only copy from the buffer to the active register during the vertical blanking interval — the period between frames when no pixels are being drawn (when vcount is greater than 480). This way the ball position only ever updates between complete frames, never mid-frame.
