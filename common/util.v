`timescale 1ns/100ps

module divide_by_n(input clk,
	           input reset,
	           output out);
    parameter N = 2;
    localparam cwidth = $clog2(N);
    reg [cwidth - 1:0] counter;

    assign out = (counter < (N / 2)) ? 1'b0 : 1'b1;

    always @(posedge clk) begin
	if (reset) begin
	  counter <= 0;
	end else begin
	  if (counter == 0) begin
	      counter <= N - 1;
	  end else begin
	      counter <= counter - 1;
          end
        end
    end
endmodule

module resetter(input      clock,
                output     reset);
    parameter count_maxval = 255;
    localparam count_width = $clog2(count_maxval);

    reg [count_width - 1:0] reset_count;
    assign reset = (reset_count == count_maxval) ? 1'b0 : 1'b1;
    initial reset_count = 'h0;

    always @(posedge clock) begin
        reset_count <= (reset_count == count_maxval) ? count_maxval : reset_count + 'h01;
    end
endmodule
