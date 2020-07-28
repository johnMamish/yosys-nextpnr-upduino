module i2c_sender_top(inout sda,
                      inout scl,

                      output spi_cs,
                      output led);
    assign spi_cs = 1'b1;
    assign led = 1'b1;

`ifdef _NOT_DEFINED
    // Special IO declarations for open-drain bidir SDA and SCL pins
    wire sda_in, sda_oe, sda_o, scl_in, scl_oe, scl_o;

    // alternative??:  .OUTPUT_ENABLE(sda_oe & sda_o)
    //                 .D_OUT_0(1'b0)
    SB_IO sda_pin(.PACKAGE_PIN(sda),
                  .LATCH_INPUT_VALUE(),
                  .CLOCK_ENABLE(),
                  .INPUT_CLK(),
                  .OUTPUT_CLK(),
                  .OUTPUT_ENABLE(sda_oe),
                  .D_OUT_1(),
                  .D_OUT_0(sda_o),
                  .D_IN_1(),
		  .D_IN_0(sda_in));
    defparam sda_pin.PIN_TYPE = 6'b101000;

    SB_IO scl_pin(.PACKAGE_PIN(scl),
                  .LATCH_INPUT_VALUE(),
                  .CLOCK_ENABLE(),
                  .INPUT_CLK(),
                  .OUTPUT_CLK(),
                  .OUTPUT_ENABLE(scl_oe),
                  .D_OUT_1(),
                  .D_OUT_0(scl_o),            // this essentially makes it an open-drain output.
                  .D_IN_1(),
		  .D_IN_0(scl_in));
    defparam scl_pin.PIN_TYPE = 6'b101000;
`endif

    // Special IO declarations for open-drain bidir SDA and SCL pins
    wire sda_in, sda_oe, sda_o, scl_in, scl_oe, scl_o;

    assign sda = sda_oe ? sda_o : 1'bz;
    assign sda_in = sda;
    assign scl = scl_oe ? scl_o : 1'bz;
    assign scl_in = scl;

    // system clock generator
    wire clk_48;
    reg clk_24;
    SB_HFOSC u_hfosc(.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk_48));
    always @(posedge clk_48) clk_24 = ~clk_24;

    wire reset;
    resetter r(.clock(clk_24), .reset(reset));

    // i2c and i2c system bus controller
    wire [7:0] sbdat_from_peripheral;
    wire       sback;
    wire       i2c_irq;
    wire       i2c_wkup;
    wire       sbclk;
    wire       sbrw;
    wire       sbstb;
    wire [7:0] sbadr;
    wire [7:0] sbdat_from_controller;
    lattice_system_bus_controller lsbc(.clock(clk_24),
                                       .reset(reset),

                                       .sbdat_from_peripheral(sbdat_from_peripheral),
                                       .sback(sback),
                                       .i2c_irq(i2c_irq),
                                       .i2c_wkup(i2c_wkup),
                                       .sbclk(sbclk),
                                       .sbrw(sbrw),
                                       .sbstb(sbstb),
                                       .sbadr(sbadr),
                                       .sbdat_to_peripheral(sbdat_from_controller));

    SB_I2C i2c1(.SBCLKI(clk_24),
	        .SBRWI(sbrw),
	        .SBSTBI(sbstb),
	        .SBADRI7(sbadr[7]),
	        .SBADRI6(sbadr[6]),
	        .SBADRI5(sbadr[5]),
	        .SBADRI4(sbadr[4]),
	        .SBADRI3(sbadr[3]),
	        .SBADRI2(sbadr[2]),
	        .SBADRI1(sbadr[1]),
	        .SBADRI0(sbadr[0]),
	        .SBDATI7(sbdat_from_controller[7]),
	        .SBDATI6(sbdat_from_controller[6]),
	        .SBDATI5(sbdat_from_controller[5]),
	        .SBDATI4(sbdat_from_controller[4]),
	        .SBDATI3(sbdat_from_controller[3]),
	        .SBDATI2(sbdat_from_controller[2]),
	        .SBDATI1(sbdat_from_controller[1]),
	        .SBDATI0(sbdat_from_controller[0]),
	        .SCLI(scl_in),
	        .SDAI(sda_in),
	        .SBDATO7(sbdat_from_peripheral[7]),
	        .SBDATO6(sbdat_from_peripheral[6]),
	        .SBDATO5(sbdat_from_peripheral[5]),
	        .SBDATO4(sbdat_from_peripheral[4]),
	        .SBDATO3(sbdat_from_peripheral[3]),
	        .SBDATO2(sbdat_from_peripheral[2]),
	        .SBDATO1(sbdat_from_peripheral[1]),
	        .SBDATO0(sbdat_from_peripheral[0]),
	        .SBACKO(sback),
	        .I2CIRQ(i2c_irq),
	        .I2CWKUP(i2c_wkup),
	        .SCLO(scl_o),
	        .SCLOE(scl_oe),
	        .SDAO(sda_o),
	        .SDAOE(sda_oe));
    defparam i2c1.I2C_SLAVE_INIT_ADDR = "0b1111100001";
    defparam i2c1.BUS_ADDR74 = "0b0010";
endmodule
