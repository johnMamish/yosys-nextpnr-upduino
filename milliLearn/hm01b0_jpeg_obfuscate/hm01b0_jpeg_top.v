`timescale 1ns/100ps

/**
 * Puts some data in at the end of a frame delimited by a vsync signal.
 *
 * Incoming vsync is active high.
 */
module frame_end_stuffer(input                      clock,
                         input                      reset,

                         input                      data_in_valid,
                         input                      vsync_in,
                         input [7:0]                data_in,

                         output reg                 state,
                         output reg                 data_out_valid,
                         output reg [7:0]           data_out,
                         output reg                 vsync_out);
    parameter delimiter_length = 32;   // should be a multiple of 8.
    parameter [(delimiter_length - 1):0] delimiter = 32'hf00f_ba11;
    localparam delimiter_index_maxvalue = (delimiter_length / 8) - 1;

    reg vsync_prev [0:1];

    always @* begin
        vsync_prev[0] = vsync_in;
    end

    localparam STATE_IMAGE = 1'b0;
    localparam STATE_DELIMITER = 1'b1;
    //reg state;
    reg [($clog2(delimiter_index_maxvalue) - 1):0] delimiter_index;
    always @(posedge clock) begin
        if (reset) begin
            data_out_valid <= 1'b0;
            dat_out <= 'hxx;
            vsync_out <= 1'b0;
            vsync_prev[1] <= 1'b0;
            state <= STATE_IMAGE;
            delimiter_index <= 'hxx;
        end else begin
            vsync_prev[1] <= vsync_prev[0];

            case (state)
                STATE_IMAGE: begin
                    data_out_valid <= data_in_valid;
                    data_out <= data_in;

                    if (!vsync_prev[0] && vsync_prev[1]) begin
                        vsync_out <= 1'b1;
                        state <= STATE_DELIMITER;
                    end else begin
                        vsync_out <= vsync_in;
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
                        vsync_out <= 1'b1;
                    end else begin
                        delimiter_index <= delimiter_index + 'h1;
                        state <= state;
                        vsync_out <= 1'b1;
                    end
                end
            endcase
        end
    end
endmodule

//`define USE_FORENCICH_I2C
`ifdef USE_FORENCICH_I2C
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
`else
    `define DEV_ID 8'h24
/**
 *
 * outputs:
 *     active     - This signal is high as long as the i2c initializer is sending data. It goes low
 *                  once all data has been sent.
 */
module i2c_initializer(input clock, //should be 12mhz
                       input reset,

                       inout hm01b0_sda,
                       inout hm01b0_scl,

                       output reg active);
    reg sda, scl;
    assign hm01b0_sda = sda ? 1'bz : 1'b0;
    assign hm01b0_scl = scl ? 1'bz : 1'b0;

    wire scl_freq;
    //A11 = 12000000/(440*(2^7)) = 213.068
    defparam div.N = 10; //120 for 100khz, 30 for 400khz
    divide_by_n div(
        .clk(clock),
        .reset(reset),
        .out(scl_freq)
    );

    reg [23:0] mem [0:159];
    //integer i;
    initial begin
        $readmemh("sparkfun_i2c_init_bytes.hex", mem);
    end

    reg [7:0] mem_adr; //2^8=256 > 160
    reg [7:0] mem_adr_next;

    reg [1:0] byte_adr; //2'b11 is dev_id
    reg [1:0] byte_adr_next;

    reg [3:0] bit_adr; //0-7, 8 is ack (9 to stop?)
    reg [3:0] bit_adr_next;

    reg sda_next;
    reg scl_next;
    reg scl_freq_prev;
    reg scl_freq_prev_prev;

    reg txing;
    reg txing_next;

    reg stopping;
    reg stopping_next;

    reg active_next;

    always @(posedge clock) begin
        sda <= sda_next;
        scl <= scl_next;
        mem_adr <= mem_adr_next;
        byte_adr <= byte_adr_next;
        bit_adr <= bit_adr_next;
        scl_freq_prev <= scl_freq;
        scl_freq_prev_prev <= scl_freq_prev;
        txing <= txing_next;
        stopping <= stopping_next;
        active <= active_next;
    end

    always @* begin
        sda_next = sda;
        scl_next = scl;
        mem_adr_next = mem_adr;
        byte_adr_next = byte_adr;
        bit_adr_next = bit_adr;
        txing_next = txing;
        stopping_next = stopping;
        active_next = active;

        if (reset) begin
            sda_next = 1'b1;
            scl_next = 1'b1;
            mem_adr_next = 8'b0;
            byte_adr_next = 2'b11;
            bit_adr_next = 4'h7;
            txing_next = 1'b0;
            stopping_next = 1'b0;
            active_next = 1'b1;
        end else if (mem_adr >= 160) begin //done with transmissions
            sda_next = 1'b1;
            active_next = 1'b0;
        end else if (scl_freq && !scl_freq_prev) begin
            scl_next = 1'b1;
        end else if (scl_freq_prev && !scl_freq_prev_prev) begin //posedge scl - start, stop
            if (stopping) begin
                sda_next = 1'b1; //sda is ack:high, stopping:low, stop condition:high
                stopping_next = 1'b0;
                mem_adr_next = mem_adr + 8'b1;
            end else begin
                if (byte_adr == 2'b11 && bit_adr == 4'h7 && !txing) begin //start
                    txing_next = 1'b1;
                    sda_next = 1'b0;
                    //mem_adr_next = mem_adr + 8'b1;
                end else if (byte_adr == 2'b11 && bit_adr == 4'h7 && txing) begin //stop
                    txing_next = 1'b0;
                    stopping_next = 1'b1;
                end
            end

        end else if (!scl_freq && scl_freq_prev) begin // && txing) begin
            scl_next = 1'b0;
        end else if (!scl_freq_prev && scl_freq_prev_prev) begin //negedge scl - transmit
            if (stopping)
                sda_next = 1'b0;
            else if (txing) begin
                bit_adr_next = bit_adr - 4'b1;

                if (!bit_adr) begin
                    byte_adr_next = byte_adr + 2'b01;
                    bit_adr_next = 4'h8;
                end

                if (bit_adr == 4'h8)
                    sda_next = 1'b1;
                else if (byte_adr == 2'b11)
                    sda_next = !(!({`DEV_ID,1'b0} & (8'b1 << bit_adr)));
                else
                    sda_next = mem[mem_adr][{2'b10 - byte_adr, bit_adr[2:0]}];

            end
        end
    end
endmodule
`endif // !`ifdef USE_FORENCICH_I2C


module hm01b0_jpeg_top(input                  osc_12m,

                       // hm01b0 connections
                       inout                  hm01b0_sda,
                       inout                  hm01b0_scl,

                       // i2c memory peripheral connections for obfuscate memory
                       inout                  obfuscate_sda,
                       inout                  obfuscate_scl,

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
    wire power_on_reset;
    wire i2c_initializer_active;
    wire post_camera_init_reset = (power_on_reset || i2c_initializer_active);
    resetter r(.clock(osc_12m), .reset(power_on_reset));
    defparam r.count_maxval = 120000;

    ////////////////////////////////////////////////
    // i2c
    wire i2c_driver_clock;
    defparam i2c_div.N = 20;
    divide_by_n i2c_div(.clk(osc_12m), .reset(power_on_reset), .out(i2c_driver_clock));

    wire i2c_reset;
    resetter i2c_resetter(.clock(i2c_driver_clock), .reset(i2c_reset));
    i2c_initializer initializer(.clock(i2c_driver_clock),
                                .reset(i2c_reset),
                                .hm01b0_sda(hm01b0_sda),
                                .hm01b0_scl(hm01b0_scl),
                                .active(i2c_initializer_active));

    ////////////////////////////////////////////////
    // obfuscation table i2c peripheral
    wire obfuscate_cipo_scl, obfuscate_cipo_sda;
    wire meta_obfuscate_copi_scl, meta_obfuscate_copi_sda;
    assign obfuscate_scl = obfuscate_cipo_scl ? 1'bz : 1'b0;
    //assign obfuscate_scl = 1'bz;
    assign meta_obfuscate_copi_scl = obfuscate_scl;
    assign obfuscate_sda = obfuscate_cipo_sda ? 1'bz : 1'b0;
    assign meta_obfuscate_copi_sda = obfuscate_sda;

    reg pipeline_obfuscate_copi_scl [0:2];
    reg pipeline_obfuscate_copi_sda [0:2];
    always @(posedge osc_12m) begin
        pipeline_obfuscate_copi_scl[0] <= meta_obfuscate_copi_scl;
        pipeline_obfuscate_copi_scl[1] <= pipeline_obfuscate_copi_scl[0];
        pipeline_obfuscate_copi_scl[2] <= pipeline_obfuscate_copi_scl[1];

        pipeline_obfuscate_copi_sda[0] <= meta_obfuscate_copi_sda;
        pipeline_obfuscate_copi_sda[1] <= pipeline_obfuscate_copi_sda[0];
        pipeline_obfuscate_copi_sda[2] <= pipeline_obfuscate_copi_sda[1];
    end

    wire obfuscate_copi_scl, obfuscate_copi_sda;
    assign obfuscate_copi_scl = pipeline_obfuscate_copi_scl[2];
    assign obfuscate_copi_sda = pipeline_obfuscate_copi_sda[2];

    wire obfuscate_ebr_select, obfuscate_ebr_wren;
    wire i2c_memory_writer_write_active;
    wire [7:0] obfuscate_data_i2c_out_ebr_in;
    i2c_memory_writer_peripheral i2c_obfuscation(.clock(osc_12m),
                                                 .reset(post_camera_init_reset),
                                                 .copi_scl(obfuscate_copi_scl),
                                                 .copi_sda(obfuscate_copi_sda),

                                                 .cipo_scl(obfuscate_cipo_scl),
                                                 .cipo_sda(obfuscate_cipo_sda),

                                                 .ebr_select(obfuscate_ebr_select),
                                                 .write_active(i2c_memory_writer_write_active),
                                                 .ebr_wren(obfuscate_ebr_wren),
                                                 .ebr_data_out(obfuscate_data_i2c_out_ebr_in),

                                                 .state_out(gpio[1:0]),
                                                 .counter_out(gpio[5:2]));

    //assign gpio[2] = obfuscate_cipo_scl;
    //assign gpio[3] = obfuscate_cipo_sda;

    reg [8:0] obfuscation_table_ebr_waddr;
    always @(posedge osc_12m) begin
        if (post_camera_init_reset) begin
            obfuscation_table_ebr_waddr <= 'h00;
        end else begin
            if (i2c_memory_writer_write_active) begin
                obfuscation_table_ebr_waddr <= (obfuscate_ebr_wren) ?
                                               (obfuscation_table_ebr_waddr + 'h1) :
                                               obfuscation_table_ebr_waddr;
            end else begin
                obfuscation_table_ebr_waddr <= 'h00;
            end
        end
    end

    ////////////////////////////////////////////////
    // obfuscation table ebr
    wire [8:0]               obfuscation_table_ebr_raddr;
    wire [7:0]               obfuscation_table_ebr_dout;
    ice40_ebr obfuscation_table(.din(obfuscate_data_i2c_out_ebr_in),
                                .write_en(obfuscate_ebr_wren),
                                .waddr(obfuscation_table_ebr_waddr),
                                .wclk(osc_12m),

                                .raddr(obfuscation_table_ebr_raddr),
                                .rclk(osc_12m),
                                .dout(obfuscation_table_ebr_dout));

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
    jfpjc jfpjc(.nreset(!post_camera_init_reset), .clock(osc_12m),

                .obfuscation_table_ebr_raddr(obfuscation_table_ebr_raddr),
                .obfuscation_table_ebr_dout(obfuscation_table_ebr_dout),

                .hm01b0_pixclk(trimmed_pixclk), .hm01b0_pixdata(hm01b0_pixdata),
                .hm01b0_hsync(trimmed_hsync), .hm01b0_vsync(trimmed_vsync),
                .hsync(jfpjc_hsync), .vsync(jfpjc_vsync), .data_out(jfpjc_data_out));
    defparam jfpjc.quant_table_file = "./quantization_table_jpeg_annex.hex";

    wire fstuff_state;
    wire fstuff_vsync_out;
    wire fstuff_data_out_valid;
    wire [7:0] fstuff_data_out;
    frame_end_stuffer fstuff(.clock(osc_12m), .reset(post_camera_init_reset),

                             .data_in_valid(jfpjc_hsync),
                             .vsync_in(jfpjc_vsync),
                             .data_in(jfpjc_data_out),

                             .state(fstuff_state),
                             .data_out_valid(fstuff_data_out_valid),
                             .data_out(fstuff_data_out),
                             .vsync_out(fstuff_vsync_out));

    defparam fstuff.delimiter_length = 2 * 8;
    defparam fstuff.delimiter = 16'hffd9;

    wire vsync_out;
    spram_uart_dual_buffer outbuf(.clock(osc_12m), .reset(post_camera_init_reset),

                                  .data_in(fstuff_data_out),
                                  .data_in_valid(fstuff_data_out_valid),
                                  .vsync_in(fstuff_vsync_out),

                                  .uart_tx(uart_tx_config_copi),
                                  .vsync_out(vsync_out));
    defparam outbuf.clock_divider = 7'd6;
    //defparam outbuf.max_address = 15'd8000;

    //assign gpio[6:0] = {uart_tx_config_copi, vsync_out, fstuff_state, osc_12m, jfpjc_vsync, jfpjc_hsync};
    //assign gpio[7:0] = {trimmed_hsync, trimmed_vsync, vsync_out, uart_tx_config_copi, jfpjc_vsync, jfpjc_hsync, hm01b0_vsync, hm01b0_hsync};
endmodule
