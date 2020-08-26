COMMON:=../../common

all: hm01b0.bin

VERILOG_FILES:=
VERILOG_FILES+=$(COMMON)/util.v
VERILOG_FILES+=$(COMMON)/uart.v
VERILOG_FILES+=hm01b0_top.v
VERILOG_FILES+=i2c_master.v
VERILOG_FILES+=i2c_init.v
VERILOG_FILES+=uart_buffer.v
VERILOG_FILES+=grayscale_downsampler.v

iverilog: $(VERILOG_FILES) i2c_init_bytes.hex
#iverilog:  $(COMMON)/util.v hm01b0_top.v
	iverilog -Wall -Wno-sensitivity-entire-array -o $@ $(filter %.v,$^)

hm01b0.bin: $(VERILOG_FILES) hm01b0.pcf hm01b0.yosys i2c_init_bytes.hex
	yosys -s hm01b0.yosys
	nextpnr-ice40 --up5k --package sg48 --pcf hm01b0.pcf --json hm01b0.json --asc hm01b0.asc
	icepack hm01b0.asc hm01b0.bin

i2c_sender_tb.vvp: $(COMMON)/util.v i2c_sender_tb.v i2c_master.v i2c_init.v
	iverilog $^ -Wall -o $@

clean:
	rm hm01b0.bin hm01b0.asc hm01b0.json i2c_sender_tb.vvp

.PHONY: clean
