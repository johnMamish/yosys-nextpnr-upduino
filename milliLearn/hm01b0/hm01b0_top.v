`timescale 1ns/100ps

/**
 * What sort of frame synchronization information do I want to come out of the ingester? I suppose
 * that I could just pass vsync through.
 *
 * This assumes that the clock runs at a considerably higher rate than pixclk... at least 6x pixclk.
 */
module ingester(input                    clock,
                input                    reset,

                input [7:0]              hm01b0_pixdata,
                input                    hm01b0_pixclk,
                input                    hm01b0_hsync,
                input                    hm01b0_vsync,

                output reg [($clog2(image_width)):0] x_idx,
                output reg               pixclk_posedge,
                output reg               vsync,
                output reg               data_valid,
                output reg [7:0]         data);
    parameter image_width = 320;
    parameter image_height = 240;
    parameter x_start_padding = 2;
    parameter x_end_padding = 2;
    parameter y_start_padding = 2;
    parameter y_end_padding = 2;

    reg hm01b0_pixclk_prev [0:1];
    reg hm01b0_hsync_prev [0:1];
    reg hm01b0_vsync_prev [0:1];
    reg [7:0] hm01b0_pixdata_prev [0:1];

    //
    always @(posedge clock) begin
        if (!reset) begin
            hm01b0_pixclk_prev[0] <= hm01b0_pixclk;
            hm01b0_pixclk_prev[1] <= hm01b0_pixclk_prev[0];
            hm01b0_pixdata_prev[0] <= hm01b0_pixdata;
            hm01b0_pixdata_prev[1] <= hm01b0_pixdata_prev[0];
            hm01b0_hsync_prev[0] <= hm01b0_hsync;
            hm01b0_hsync_prev[1] <= hm01b0_hsync_prev[0];
            hm01b0_vsync_prev[0] <= hm01b0_vsync;
            hm01b0_vsync_prev[1] <= hm01b0_vsync_prev[0];
        end else begin
            hm01b0_pixclk_prev[0] <= 'h0; hm01b0_pixclk_prev[1] <= 'h0;
            hm01b0_pixdata_prev[0] <= 'h0; hm01b0_pixdata_prev[1] <= 'h0;
            hm01b0_hsync_prev[0] <= 'h0; hm01b0_hsync_prev[1] <= 'h0;
            hm01b0_vsync_prev[0] <= 'h0; hm01b0_vsync_prev[1] <= 'h0;
        end
    end

    //reg pixclk_posedge;
    always @* begin
        pixclk_posedge = !hm01b0_pixclk_prev[0] && hm01b0_pixclk;
        vsync = hm01b0_vsync;
    end

    //reg [($clog2(image_width)):0] x_idx;
    reg [($clog2(image_height)):0] y_idx;
    always @(posedge clock) begin
        if (!reset) begin
            if (!hm01b0_vsync) begin
                x_idx <= 'h0;
                y_idx <= 'h0;
                data_valid <= 1'b0;
                data <= 8'hxx;
            end else if (pixclk_posedge) begin
                if (x_idx == (image_width + x_start_padding + x_end_padding - 1)) begin
                    x_idx <= 'h0;
                    if (y_idx == (image_height + y_start_padding + y_end_padding - 1)) begin
                        y_idx <= 'h0;
                    end else begin
                        y_idx <= y_idx + 'h1;
                    end
                end else begin
                    x_idx <= x_idx + 'h1;
                end

                if ((x_idx >= x_start_padding) && (x_idx < (image_width + x_end_padding)) &&
                    (y_idx >= y_start_padding) && (y_idx < (image_height + y_end_padding))) begin
                    data_valid <= 1'b1;
                    data <= hm01b0_pixdata_prev[1];
                end else begin
                    data_valid <= 1'b0;
                    data <= 8'hxx;
                end
            end else begin
                x_idx <= x_idx;
                y_idx <= y_idx;
                data_valid <= 1'b0;
                data <= 8'hxx;
            end
        end else begin
            x_idx <= 'h0;
            y_idx <= 'h0;
            data_valid <= 1'b0;
            data <= 8'hxx;
        end
    end
endmodule


/**
 * Plug an image into the front end, and it will echo the image, but with a sequence added at the
 * end of each frame, for an end-of-frame alignment marker
 */
module frame_end_stuffer(input                      clock,
                         input                      reset,

                         input                      data_in_valid,
                         input                      vsync,
                         input [7:0]                data_in,

                         output reg                 state,
                         output reg                 data_out_valid,
                         output reg [7:0]           data_out);
    localparam delimiter_length = 32;
    localparam [(delimiter_length - 1):0] delimiter = 32'hf00f_ba11;
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


                /*
                 data_out <= gen_count;
                 if (data_out_valid) begin

                    gen_count <= (gen_count >= 8'd119) ? 8'd100 : gen_count + 'h1;
                end else begin
                    gen_count <= gen_count;
                end*/
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

module hm01b0_top(input                  osc_12m,

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
                  output [5:0] gpio,

                  output gpio43_hiz);
    ///////////////////////////////////////////////
    // Debug GPIOs
    assign config_ps = 1'b1;

    assign hm01b0_trig_debug_led = uart_tx_config_copi;
    /*assign gpio[0] = hm01b0_sda;
    assign gpio[1] = hm01b0_scl;
    assign gpio[2] = hm01b0_pixclk;
    assign gpio[3] = hm01b0_hsync;
    assign gpio[4] = hm01b0_vsync;
    assign gpio[5] = uart_tx_config_copi;*/

    //assign gpio[2:0] = {hm01b0_vsync, hm01b0_hsync, hm01b0_pixclk};

    /*assign gpio[4:0] = hm01b0_pixdata[7:3];
    assign gpio[5]   = hm01b0_pixclk;
    assign gpio[6]   = hm01b0_vsync;
    assign gpio[7]   = hm01b0_hsync;*/

    assign gpio43_hiz = (hm01b0_vsync) ? (1'bz) : (1'b0);

    ////////////////////////////////////////////////
    // reset circuit
    wire reset;
    resetter r(.clock(osc_12m), .reset(reset));

    ////////////////////////////////////////////////
    // i2c
    i2c_initializer initializer(.clock(osc_12m), .reset(reset), .hm01b0_sda(hm01b0_sda), .hm01b0_scl(hm01b0_scl));

    ////////////////////////////////////////////////
    // hm01b0 mck
    assign hm01b0_mck = osc_12m;

    ////////////////////////////////////////////////
    // Ingest, downsample, pad image, and transmit over UART.
    wire ingester_vsync;
    wire ingester_data_out_valid;
    wire [7:0] ingester_data_out;
    wire pixclk_posedge;
    wire [7:0] xidx;
    ingester ing(.clock(osc_12m), .reset(reset),
                 .hm01b0_pixdata(hm01b0_pixdata), .hm01b0_pixclk(hm01b0_pixclk),
                 .hm01b0_hsync(hm01b0_hsync), .hm01b0_vsync(hm01b0_vsync),
                 .vsync(ingester_vsync), .data_valid(ingester_data_out_valid), .data(ingester_data_out));

    wire downsampler_vsync;
    wire downsampler_data_out_valid;
    wire [7:0] downsampler_data_out;
    grayscale_downsampler ds(.clock(osc_12m), .reset(reset),
                             .vsync_in(ingester_vsync), .data_in_valid(ingester_data_out_valid), .data_in(ingester_data_out),
                             .vsync_out(downsampler_vsync), .data_out_valid(downsampler_data_out_valid), .data_out(downsampler_data_out));
    defparam ds.bin_width = 2;
    defparam ds.bin_height = 2;

    wire frame_end_stuffer_data_out_valid;
    wire [7:0] frame_end_stuffer_data_out;
    wire state;
    frame_end_stuffer frame_end_stuffer(.clock(osc_12m), .reset(reset), .state(state),
                                        .data_in_valid(downsampler_data_out_valid),
                                        .vsync(downsampler_vsync),
                                        .data_in(downsampler_data_out),
                                        .data_out_valid(frame_end_stuffer_data_out_valid),
                                        .data_out(frame_end_stuffer_data_out));

    spram_uart_buffer outbuf(.clock(osc_12m), .reset(reset),
                             .data_in(frame_end_stuffer_data_out),
                             .data_in_valid(frame_end_stuffer_data_out_valid),
                             .uart_tx(uart_tx_config_copi));
    defparam outbuf.clock_divider = 7'd6;
    defparam outbuf.max_address = 15'd19200 / 1;
    assign gpio[5:0] = { state, frame_end_stuffer_data_out_valid, ingester_data_out_valid, hm01b0_vsync, hm01b0_hsync, hm01b0_pixclk};
endmodule
