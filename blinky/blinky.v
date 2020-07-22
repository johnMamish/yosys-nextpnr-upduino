module blinker(input       clock,
               input       reset,
               output      blink);
    reg [23:0] counter;

    assign blink = counter[22];

    always @(posedge clock) begin
        if (!reset) begin
            counter <= counter + 24'h1;
        end else begin
            counter <= 24'h0;
        end
    end
endmodule


module resetter(input      clock,
                output     reset);
    reg [7:0] reset_count;
    initial reset_count = 8'h00;

    always @(posedge clock) begin
        reset_count <= (reset_count == 8'hff) ? 8'hff : reset_count + 8'h01;;
    end
endmodule


module top(output led);
    wire clk_48;
    SB_HFOSC u_hfosc(.CLKHFPU(1'b1),
		     .CLKHFEN(1'b1),
		     .CLKHF(clk_48));

    wire reset;
    resetter r(.clock(clk_48),
               .reset(reset));

    blinker b(.clock(clk_48),
              .reset(reset),
              .blink(led));
endmodule
