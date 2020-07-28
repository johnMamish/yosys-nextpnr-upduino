`timescale 1ns/100ps

module blinker(input       clock,
               input       reset,
               output      blink);
    reg [23:0] counter;

    assign blink = counter[21];

    always @(posedge clock) begin
        if (!reset) begin
            counter <= counter + 24'h1;
        end else begin
            counter <= 24'h0;
        end
    end
endmodule

// The name blinky_top is arbitrary. It just needs to be specified in the yosys synthesis script
// with the -top argument passed into synth_ice40
module blinky_top(output spi_cs,
                  output led);

    assign spi_cs = 1'b1;

    // This oscillator is a hard IP core inside the ice40.
    wire clk_48;
    SB_HFOSC u_hfosc(.CLKHFPU(1'b1),
		     .CLKHFEN(1'b1),
		     .CLKHF(clk_48));

    // Module "resetter" is defined in ../common/util.v
    wire reset;
    resetter r(.clock(clk_48),
               .reset(reset));

    blinker b(.clock(clk_48),
              .reset(reset),
              .blink(led));
endmodule
