all: i2c_sender.bin

i2c_sender.bin: i2c_sender_top.v i2c_sender.v i2c_sender.yosys ../common/util.v i2c_sender.pcf
	yosys -s i2c_sender.yosys
	nextpnr-ice40 --up5k --package sg48 --pcf i2c_sender.pcf --json i2c_sender.json --asc i2c_sender.asc
	icepack i2c_sender.asc i2c_sender.bin

i2c_sender_backend_tb.vvp: i2c_sender.v i2c_sender_backend_tb.v ../common/util.v
	iverilog -Wall -Wno-sensitivity-entire-array -o $@ $^

#../common/lattice_i2c/lattice_i2c.v

clean:
	rm i2c_sender.asc i2c_sender.bin i2c_sender.json i2c_sender_backend_tb.vvp



.PHONY: clean
