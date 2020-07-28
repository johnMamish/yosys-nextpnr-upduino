module i2c_sender_top(inout sda,
                      inout scl,

                      output spi_cs,

                      output [5:0] debug_leds);
    assign spi_cs = 1'b1;

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

    wire reset, reset2;
    resetter r(.clock(clk_24), .reset(reset));
    resetter r2(.clock(clk_24), .reset(reset2));
    defparam r2.count_maxval = 1023;

    wire sysclk;
    divide_by_n #(.N(48)) div(.clk(clk_48), .reset(reset), .out(sysclk));

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
    i2c_sender send(.clock(sysclk),
                    .reset(reset2),

                    .sbdat_from_peripheral(sbdat_from_peripheral),
                    .sback(sback),
                    .i2c_irq(i2c_irq),
                    .i2c_wkup(i2c_wkup),
                    .sbclk(sbclk),
                    .sbrw(sbrw),
                    .sbstb(sbstb),
                    .sbadr(sbadr),
                    .sbdat_to_peripheral(sbdat_from_controller));

                    //.expose_sbc_state(debug_leds[2:1]));
                    //.expose_state(debug_leds[4:1]));

    assign debug_leds[0] = sysclk;
    assign debug_leds[2:1] = sbadr[5:4];
    assign debug_leds[3] = sback;
    assign debug_leds[4] = sbrw;
    assign debug_leds[5] = sbstb;
    SB_I2C i2c1(.SBCLKI(sysclk),
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
    defparam i2c1.BUS_ADDR74 = "0b0001";
endmodule
