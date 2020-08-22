`timescale 1ns/100ps

module uart_tx(input             clock,
	       input             reset,
	       input             baud_clock,

               input             data_valid,
               input [7:0]       data,

	       output reg        uart_tx,
	       output reg        uart_busy);
    reg [9:0] shift_register;
    reg [3:0] shift_count;

    reg baud_clock_prev;

    always @(posedge clock) begin
        if (!reset) begin
            baud_clock_prev <= baud_clock;

            if (uart_busy) begin
                if (shift_count == 4'd10) begin
                    shift_register <= 10'hxxx;
                    shift_count <= 4'h0;
                    uart_busy <= 1'b0;
                    uart_tx <= uart_tx;
                end else begin
                    if (baud_clock && !baud_clock_prev) begin
                        shift_register <= { 1'b0, shift_register[9:1] };
                        shift_count <= shift_count + 4'h1;
                        uart_busy <= 1'b1;
                        uart_tx <= shift_register[0];
                    end else begin
                        shift_register <= shift_register;
                        shift_count <= shift_count;
                        uart_busy <= uart_busy;
                        uart_tx <= uart_tx;
                    end
                end
            end else begin
                uart_tx <= 1'b1;
                if (data_valid) begin
                    shift_register <= { 1'b1, data, 1'b0 };
                    shift_count <= 4'h0;
                    uart_busy <= 1'b1;
                end else begin
                    shift_register <= shift_register;
                    shift_count <= shift_count;
                    uart_busy <= uart_busy;
                end
            end
        end else begin
            shift_register <= 9'hxxx;
            shift_count <= 4'h0;
            uart_tx <= 1'b1;
            uart_busy <= 1'b0;
            baud_clock_prev <= baud_clock;
        end
    end
endmodule
