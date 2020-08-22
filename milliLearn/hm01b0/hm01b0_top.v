`timescale 1ns/100ps

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
    assign config_ps = 1'b1;

    assign hm01b0_trig_debug_led = uart_tx_config_copi;
    /*assign gpio[0] = hm01b0_sda;
    assign gpio[1] = hm01b0_scl;
    assign gpio[2] = hm01b0_pixclk;
    assign gpio[3] = hm01b0_hsync;
    assign gpio[4] = hm01b0_vsync;
    assign gpio[5] = uart_tx_config_copi;*/

    assign gpio[4:0] = hm01b0_pixdata[7:3];
    assign gpio[5]   = hm01b0_pixclk;
    assign gpio[6]   = hm01b0_vsync;
    assign gpio[7]   = hm01b0_hsync;

    assign gpio43_hiz = (hm01b0_vsync) ? (1'bz) : (1'b0);

    ////////////////////////////////////////////////
    // reset circuit
    wire reset;
    resetter r(.clock(osc_12m), .reset(reset));

    ////////////////////////////////////////////////
    // i2c
    wire sda_in, sda_o, scl_in, scl_o;
    assign hm01b0_sda = sda_o ? 1'bz : 1'b0;
    assign sda_in = sda;
    assign hm01b0_scl = scl_o ? 1'bz : 1'b0;
    assign scl_in = scl;

    wire [6:0] i2c_init_cmd_address;
    wire i2c_init_cmd_start, i2c_init_cmd_read, i2c_init_cmd_write, i2c_init_cmd_write_multiple;
    wire i2c_init_cmd_stop, i2c_init_cmd_valid, i2c_init_cmd_ready;
    wire [7:0] i2c_init_data_controller_to_peripheral;
    wire i2c_init_data_controller_to_peripheral_valid, i2c_init_data_controller_to_peripheral_ready;
    wire i2c_init_data_controller_to_peripheral_last;
    wire i2c_init_busy, i2c_init_start;
    i2c_init i2c_init(.clk(osc_12m),
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

    pulse_one i2c_init_start_pulse(.clock(osc_12m), .reset(reset), .pulse(i2c_init_start));
    defparam i2c_init_start_pulse.pulse_delay = 50000;
    defparam i2c_init_start_pulse.pulse_width = 4;

    i2c_master i2c_master(.clk(osc_12m),
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
                          //.data_out_ready(i2c_init_data_controller_to_peripheral_ready),
                          .data_out_last(),

                          .scl_i(scl_in), .scl_o(scl_o), .scl_t(),
                          .sda_i(sda_in), .sda_o(sda_o), .sda_t(),

                          // unused
                          .busy(), .bus_control(), .bus_active(), .missed_ack(),

                          .prescale(16'd16), .stop_on_idle(1'b1));

    ////////////////////////////////////////////////
    // hm01b0 mck
    assign hm01b0_mck = osc_12m;

    ////////////////////////////////////////////////
    // Print pixel counts per frame over UART
    reg pixclk_prev [0:1];
    reg [23:0] pix_count;
    reg [23:0] pix_count_latch;
    always @(posedge osc_12m) begin
        pixclk_prev[0] <= hm01b0_pixclk;
        pixclk_prev[1] <= pixclk_prev[0];

        //pix_count_latch <= 24'hf00fba;

        if (pixclk_prev[0] && !pixclk_prev[1]) begin
            case ({hm01b0_vsync, hm01b0_hsync})
                2'b11: begin pix_count <= pix_count + 24'h0001; pix_count_latch <= pix_count + 24'h0001; end
                2'b10: begin pix_count <= pix_count; pix_count_latch <= pix_count_latch; end
                2'b01: begin pix_count <= 24'h0000; pix_count_latch <= pix_count_latch; end
                2'b00: begin pix_count <= 24'h0000; pix_count_latch <= pix_count_latch; end
            endcase
        end else begin
            case ({hm01b0_vsync, hm01b0_hsync})
                2'b11: begin pix_count <= pix_count; pix_count_latch <= pix_count_latch; end
                2'b10: begin pix_count <= pix_count; pix_count_latch <= pix_count_latch; end
                2'b01: begin pix_count <= 24'h0000; pix_count_latch <= pix_count_latch; end
                2'b00: begin pix_count <= 24'h0000; pix_count_latch <= pix_count_latch; end
            endcase
        end
    end

    wire clk_0_230400;
    divide_by_n #(.N(52)) div_0_230400(.clk(osc_12m), .reset(1'b0), .out(clk_0_230400));

    reg uart_strobe;
    reg [7:0] uart_data;
    wire uart_busy;
    uart_tx uart(.clock(osc_12m),
                 .reset(reset),
                 .baud_clock(clk_0_230400),

                 .data_valid(uart_strobe),
                 .data(uart_data),

                 .uart_tx(uart_tx_config_copi),
                 .uart_busy(uart_busy));

    localparam CHARS_IN_STRING = 4'd8;
    wire [(CHARS_IN_STRING * 8) - 1:0] uart_count_in_str;
    assign uart_count_in_str[8 * 6 +: 8] = 8'h0d;
    assign uart_count_in_str[8 * 7 +: 8] = 8'h0a;
    generate
        genvar i;
        for (i = 0; i < 6; i = i + 1) begin
            hexdigit h(.num(pix_count_latch[4 * i +: 4]), .ascii(uart_count_in_str[8 * (6 - 1 - i) +: 8]));
        end
    endgenerate

    reg hm01b0_vsync_prev [0:3];
    reg hm01b0_hsync_prev [0:3];
    generate
        genvar i;
        for (i = 0; i < 4; i = i + 1) begin
            if (i == 0) begin
                always @(posedge osc_12m) begin
                    hm01b0_vsync_prev[i] <= hm01b0_vsync; hm01b0_hsync_prev[i] <= hm01b0_hsync;
                end
            end else begin
                always @(posedge osc_12m) begin
                    hm01b0_vsync_prev[i] <= hm01b0_vsync_prev[i - 1]; hm01b0_hsync_prev[i] <= hm01b0_hsync_prev[i - 1];
                end
            end
        end
    endgenerate

    reg [3:0] uart_tx_idx;
    reg [1:0] uart_tx_state;
`define UART_TX_STATE_WAITING_HM01B0 2'h0
`define UART_TX_STATE_UART_BUSY 2'h1
`define UART_TX_STATE_UART_STROBE 2'h2
    wire hm01b0_vsync_falling_edge;
    assign hm01b0_vsync_falling_edge = hm01b0_vsync_prev[1] && !hm01b0_vsync_prev[0];
    always @(posedge osc_12m) begin
        if (!reset) begin
            case (uart_tx_state)
                `UART_TX_STATE_WAITING_HM01B0: begin
                    uart_tx_idx <= 4'h0;
                    uart_tx_state <= hm01b0_vsync_falling_edge ?
                                     `UART_TX_STATE_UART_STROBE : `UART_TX_STATE_WAITING_HM01B0;
                end

                `UART_TX_STATE_UART_STROBE: begin
                    uart_tx_idx <= (uart_tx_idx == (CHARS_IN_STRING - 1)) ? 4'h0 : (uart_tx_idx + 4'h1);
                    uart_tx_state <= `UART_TX_STATE_UART_BUSY;
                end

                `UART_TX_STATE_UART_BUSY: begin
                    uart_tx_idx <= uart_tx_idx;
                    if (uart_busy) begin
                        uart_tx_state <= `UART_TX_STATE_UART_BUSY;
                    end else begin
                        uart_tx_state <= (uart_tx_idx == 4'h0) ?
                                         `UART_TX_STATE_WAITING_HM01B0 : `UART_TX_STATE_UART_STROBE;
                    end
                end

                default: begin
                    uart_tx_idx <= 4'h0;
                    uart_tx_state <= `UART_TX_STATE_WAITING_HM01B0;
                end
            endcase
        end else begin
            uart_tx_state <= `UART_TX_STATE_WAITING_HM01B0;
            uart_tx_idx <= 4'h0;
        end
    end

    always @* begin
        uart_data = uart_count_in_str[8 * uart_tx_idx +: 8];
        uart_strobe = uart_tx_state == `UART_TX_STATE_UART_STROBE;
    end
endmodule
