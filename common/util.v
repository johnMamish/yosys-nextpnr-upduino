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
    assign reset = (reset_count == 8'hff) ? 1'b0 : 1'b1;

    reg [7:0] reset_count;
    initial reset_count = 8'h00;

    always @(posedge clock) begin
        reset_count <= (reset_count == 8'hff) ? 8'hff : reset_count + 8'h01;
    end
endmodule
