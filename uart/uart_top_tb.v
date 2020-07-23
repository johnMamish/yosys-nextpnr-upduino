`timescale 1ns/100ps

module uart_top_tb();
    wire spi_cs, uart_tx, led;

    uart_top ut(.spi_cs(spi_cs),
                .uart_tx(uart_tx),
                .led(led));

    initial begin
        $dumpfile("uart_top_tb.vcd");
        $dumpvars(0, uart_top_tb);

        #1000000000;
        $finish;
    end
endmodule
