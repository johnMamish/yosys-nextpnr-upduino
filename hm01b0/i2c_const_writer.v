/**
 * This module acts as an i2c controller device. It just writes a bunch of constants to the hm01b0
 * over i2c. These constants were found using a saleae logic analyzer on the upduino board running
 * its shipped fpga bitstream.
 */
module i2c_const_writer(input                clock,
                        input                reset,

                        inout                sda,
                        inout                scl);

    wire sda_in, sda_oe, scl_in, scl_oe;

    SB_IO sda_pin(.PACKAGE_PIN(sda),
                  .LATCH_INPUT_VALUE(),
                  .CLOCK_ENABLE(),
                  .INPUT_CLK(),
                  .OUTPUT_CLK(),
                  .OUTPUT_ENABLE(sda_oe),
                  .D_OUT_1(),
                  .D_OUT_0(1'b0),            // this essentially makes it an open-drain output.
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
                  .D_OUT_0(1'b0),            // this essentially makes it an open-drain output.
                  .D_IN_1(),
		  .D_IN_0(scl_in));
    defparam scl_pin.PIN_TYPE = 6'b101000;

    reg [6:0] slave_addr_reg;

    i2c_master_controller u_i2c_master_controller(.i_scl_in(scl_in),
                                                  .o_scl_oe(scl_oe),
                                                  .i_sda_in(sda_in),
                                                  .o_sda_oe(sda_oe),
                                                  .o_int_n(),

                                                  .i_slave_addr_reg(i_slave_addr_reg),
                                                  .i_byte_cnt_reg(i_byte_cnt_reg),
                                                  .i_clk_div_lsb(i_clk_div_lsb),
                                                  .i_config_reg(i_config_reg),
                                                  .i_mode_reg(i_mode_reg),
                                                  .o_cmd_status_reg(o_cmd_status_reg),
                                                  .o_start_ack(o_start_ack),
                                                  .i_transmit_data(i_transmit_data),
                                                  .o_transmit_data_request(o_transmit_data_request),
                                                  .o_received_data_valid(o_received_data_valid),
                                                  .o_receive_data(o_receive_data),

                                                  .i_rst_n       (i_rst_n),
                                                  .i_clk              (i_clk));

endmodule
