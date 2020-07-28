`timescale 1ns/100ps

module uart_top(output spi_cs,
                output uart_tx,
                output led);
    assign spi_cs = 1'b1;

    // This oscillator is a hard IP core inside the ice40.
    wire clk_48;
    SB_HFOSC u_hfosc(.CLKHFPU(1'b1),
		     .CLKHFEN(1'b1),
		     .CLKHF(clk_48));
    reg clk_24;
    always @(posedge clk_48) begin
        clk_24 = ~clk_24;
    end

    // "resetter" is defined in ../common/util.v
    wire reset;
    resetter r(.clock(clk_24),
               .reset(reset));

    // "divide_by_n" is defined in ../common/util.v
    wire baud_clock;
    divide_by_n #(.N(417)) div(.clk(clk_48),
                               .reset(reset),
                               .out(baud_clock));

    reg [7:0] data;
    wire data_valid;
    wire uart_busy;
    uart_tx ut(.clock(clk_24),
               .reset(reset),
               .baud_clock(baud_clock),
               .data_valid(data_valid),
               .data(data),
               .uart_tx(uart_tx),
               .uart_busy(uart_busy));

    localparam count_maxval = 24'h20_0000;
    reg [23:0] count;
    assign data_valid = (count == count_maxval);
    assign led = (count > 24'h00_8000);
    always @(posedge clk_24) begin
        if (reset) begin
            count <= 24'h0;
            data <= 8'h61;
        end else begin
            if (count == count_maxval) begin
                count <= 24'h0;
                data <= (data == 8'h7a) ? 8'h61 : data + 8'h01;
            end else begin
                count <= count + 24'h1;
                data <= data;
            end
        end
    end
endmodule
