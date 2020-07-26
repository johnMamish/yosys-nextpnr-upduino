all: uart.bin

uart.bin: uart_top.v uart.pcf uart.yosys
	yosys -s uart.yosys
	nextpnr-ice40 --up5k --package sg48 --pcf uart.pcf --json uart.json --asc uart.asc
	icepack uart.asc uart.bin

uart_top_tb.vvp: uart_top.v uart.v sb_hfosc.v uart_top_tb.v
	iverilog $^ -Wall -o $@

clean:
	rm uart.bin uart.asc uart.json uart_top.vvp

.PHONY: clean
