`timescale 1ns/100ps

module frame_end_stuffer(input                      clock,
                         input                      reset,

                         input                      data_in_valid,
                         input                      vsync,
                         input [7:0]                data_in,

                         output reg                 state,
                         output reg                 data_out_valid,
                         output reg [7:0]           data_out);
    parameter delimiter_length = 32;   // should be a multiple of 8.
    parameter [(delimiter_length - 1):0] delimiter = 32'hf00f_ba11;
    localparam delimiter_index_maxvalue = (delimiter_length / 8) - 1;

    reg vsync_prev [0:1];

    always @* begin
        vsync_prev[0] = vsync;
    end

    localparam STATE_IMAGE = 1'b0;
    localparam STATE_DELIMITER = 1'b1;
    //reg state;
    reg [($clog2(delimiter_index_maxvalue) - 1):0] delimiter_index;
    reg [7:0] gen_count;
    always @(posedge clock) begin
        vsync_prev[1] <= vsync_prev[0];

        case (state)
            STATE_IMAGE: begin
                data_out_valid <= data_in_valid;
                data_out <= data_in;
                if (!vsync_prev[0] && vsync_prev[1]) begin
                    state <= STATE_DELIMITER;
                end else begin
                    state <= state;
                end
                delimiter_index <= 'h0;
            end

            STATE_DELIMITER: begin
                data_out_valid <= 1'b1;
                data_out <= delimiter[(((delimiter_length / 8) - delimiter_index - 1) * 8) +: 8];

                if (delimiter_index == delimiter_index_maxvalue) begin
                    delimiter_index <= 'h0;
                    state <= STATE_IMAGE;
                end else begin
                    delimiter_index <= delimiter_index + 'h1;
                    state <= state;
                end
            end
        endcase
    end
endmodule

module i2c_initializer(input                  clock,
                       input                  reset,
                       inout                  hm01b0_sda,
                       inout                  hm01b0_scl);
    wire sda_in, sda_o, scl_in, scl_o;
    assign hm01b0_sda = sda_o ? 1'bz : 1'b0;
    assign sda_in = hm01b0_sda;
    assign hm01b0_scl = scl_o ? 1'bz : 1'b0;
    assign scl_in = hm01b0_scl;

    wire [6:0] i2c_init_cmd_address;
    wire i2c_init_cmd_start, i2c_init_cmd_read, i2c_init_cmd_write, i2c_init_cmd_write_multiple;
    wire i2c_init_cmd_stop, i2c_init_cmd_valid, i2c_init_cmd_ready;
    wire [7:0] i2c_init_data_controller_to_peripheral;
    wire i2c_init_data_controller_to_peripheral_valid, i2c_init_data_controller_to_peripheral_ready;
    wire i2c_init_data_controller_to_peripheral_last;
    wire i2c_init_busy, i2c_init_start;
    i2c_init i2c_init(.clk(clock),
                      .rst(reset),
                      .cmd_address(i2c_init_cmd_address),
                      .cmd_start(i2c_init_cmd_start),
                      .cmd_read(i2c_init_cmd_read),
                      .cmd_write(i2c_init_cmd_write),
                      .cmd_write_multiple(i2c_init_cmd_write_multiple),
                      .cmd_stop(i2c_init_cmd_stop),
                      .cmd_valid(i2c_init_cmd_valid),
                      .cmd_ready(i2c_init_cmd_ready),

                      .data_out(i2c_init_data_controller_to_peripheral),
                      .data_out_valid(i2c_init_data_controller_to_peripheral_valid),
                      .data_out_ready(i2c_init_data_controller_to_peripheral_ready),
                      .data_out_last(i2c_init_data_controller_to_peripheral_last),

                      .busy(i2c_init_busy),
                      .start(i2c_init_start));

    pulse_one i2c_init_start_pulse(.clock(clock), .reset(reset), .pulse(i2c_init_start));
    defparam i2c_init_start_pulse.pulse_delay = 50000;
    defparam i2c_init_start_pulse.pulse_width = 4;

    i2c_master i2c_master(.clk(clock),
                          .rst(reset),
                          .cmd_address(i2c_init_cmd_address),
                          .cmd_start(i2c_init_cmd_start),
                          .cmd_read(i2c_init_cmd_read),
                          .cmd_write(i2c_init_cmd_write),
                          .cmd_write_multiple(i2c_init_cmd_write_multiple),
                          .cmd_stop(i2c_init_cmd_stop),
                          .cmd_valid(i2c_init_cmd_valid),
                          .cmd_ready(i2c_init_cmd_ready),

                          .data_in(i2c_init_data_controller_to_peripheral),
                          .data_in_valid(i2c_init_data_controller_to_peripheral_valid),
                          .data_in_ready(i2c_init_data_controller_to_peripheral_ready),
                          .data_in_last(i2c_init_data_controller_to_peripheral_last),

                          .data_out(),
                          .data_out_valid(),
                          .data_out_ready(1'bz),
                          .data_out_last(),

                          .scl_i(scl_in), .scl_o(scl_o), .scl_t(),
                          .sda_i(sda_in), .sda_o(sda_o), .sda_t(),

                          // unused
                          .busy(), .bus_control(), .bus_active(), .missed_ack(),

                          .prescale(16'd16), .stop_on_idle(1'b1));
endmodule

module hm01b0_jpeg_top(input                  osc_12m,

                       // hm01b0 connections
                       inout                  hm01b0_sda,
                       inout                  hm01b0_scl,

                       input [7:0]            hm01b0_pixdata,
                       input                  hm01b0_pixclk,
                       input                  hm01b0_hsync,
                       input                  hm01b0_vsync,

                       output                 hm01b0_mck,

                       // assorted debug connections
                       output config_ps,
                       output uart_tx_config_copi,
                       output hm01b0_trig_debug_led,

                       // using these as debug copies of sda and scl
                       output [6:0] gpio,

                       output gpio43_hiz);
    ///////////////////////////////////////////////
    // Debug GPIOs
    assign config_ps = 1'b1;

    assign hm01b0_trig_debug_led = uart_tx_config_copi;
    assign gpio43_hiz = (hm01b0_vsync) ? (1'bz) : (1'b0);

    ////////////////////////////////////////////////
    // reset circuit
    wire reset;
    resetter r(.clock(osc_12m), .reset(reset));
    defparam r.count_maxval = 12000000;

    ////////////////////////////////////////////////
    // i2c
    i2c_initializer initializer(.clock(osc_12m), .reset(reset), .hm01b0_sda(hm01b0_sda), .hm01b0_scl(hm01b0_scl));

    ////////////////////////////////////////////////
    // hm01b0 mck
    assign hm01b0_mck = osc_12m;

    ////////////////////////////////////////////////
    // trim edges of image
    wire trimmed_pixclk, trimmed_hsync, trimmed_vsync;
    vsync_hsync_roi trimmer(.pixclk_in(hm01b0_pixclk), .hsync_in(hm01b0_hsync), .vsync_in(hm01b0_vsync),
                            .pixclk_out(trimmed_pixclk), .hsync_out(trimmed_hsync), .vsync_out(trimmed_vsync));

    ////////////////////////////////////////////////
    // compress and send over UART
    wire jfpjc_vsync, jfpjc_hsync;
    wire [7:0] jfpjc_data_out;
    jfpjc jfpjc(.nreset(!reset), .clock(osc_12m),
                .hm01b0_pixclk(trimmed_pixclk), .hm01b0_pixdata(hm01b0_pixdata),
                .hm01b0_hsync(trimmed_hsync), .hm01b0_vsync(trimmed_vsync),
                .hsync(jfpjc_hsync), .vsync(jfpjc_vsync), .data_out(jfpjc_data_out));
    defparam jfpjc.quant_table_file = "./quantization_table_jpeg_annex.hex";

    wire fstuff_state;
    wire fstuff_data_out_valid;
    wire [7:0] fstuff_data_out;
    frame_end_stuffer fstuff(.clock(osc_12m), .reset(reset),
                             .data_in_valid(jfpjc_hsync), .vsync(jfpjc_vsync), .data_in(jfpjc_data_out),
                             .state(fstuff_state), .data_out_valid(fstuff_data_out_valid), .data_out(fstuff_data_out));
    defparam fstuff.delimiter_length = 2 * 8;
    defparam fstuff.delimiter = 16'hffd9;

    spram_uart_buffer outbuf(.clock(osc_12m), .reset(reset),
                             .data_in(fstuff_data_out),
                             .data_in_valid(fstuff_data_out_valid),
                             .uart_tx(uart_tx_config_copi));
    defparam outbuf.clock_divider = 7'd6;
    defparam outbuf.max_address = 15'd8000;
    assign gpio[6:0] = {fstuff_state, osc_12m, jfpjc_vsync, jfpjc_hsync, trimmed_vsync, trimmed_hsync, trimmed_pixclk};
endmodule
