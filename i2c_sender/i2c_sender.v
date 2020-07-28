`timescale 1ns/100ps


/**
 * This is a convenience module which manages the super simple 3-state "System Bus Interface"
 * that's described in Lattice TN1276. It looks like the "System Bus Interface" in TN1276 is an
 * early version of what Lattice later calls their "Lattice Memory Mapped Interface" (LMMI). The
 * "System Bus Interface" described in TN1276 appears to be a subset of LMMI.
 */
module lattice_system_bus_controller(input                clock,
                                     input                reset,

                                     // i/o from 'upstream' device
                                     input [7:0]          addr,
                                     input [7:0]          write_data,
                                     input                start_transaction,
                                     input                read_write,

                                     output               ready,
                                     output reg [7:0]     read_data,

                                     // i/o from hardened I2C ip.
                                     input [7:0]          sbdat_from_peripheral,
                                     input                sback,
                                     input                i2c_irq,
                                     input                i2c_wkup,

                                     output               sbclk,
                                     output reg           sbrw,
                                     output reg           sbstb,
                                     output reg [7:0]     sbadr,
                                     output reg [7:0]     sbdat_to_peripheral,

                                     output         [1:0] expose_state);
    assign sbclk = clock;

`define SBRW_READ 1'b0
`define SBRW_WRITE 1'b1

`define S_0  0
`define S_1  1
`define S_2  2
    reg [1:0] state;
    reg [1:0] state_next;

    reg busy;
    reg busy_next;
    reg sbrw_next;
    reg [7:0] sbadr_next;
    reg [7:0] sbdat_to_peripheral_next;
    reg [7:0] read_data_next;

    // severe multi-module latch risk here...
    assign ready = (!busy && !start_transaction) || (sback);
    assign expose_state = state;

    always @* begin
        // default values
        state_next = `S_0;
        sbrw_next = 1'b0;
        sbadr_next = 8'h00;
        sbdat_to_peripheral_next = 8'h00;
        busy_next = 1'b0;
        read_data_next = 8'hxx;
        sbstb = 1'b0;
        case (state)
            `S_0: begin
                if (start_transaction) begin
                    state_next = `S_1;
                    sbrw_next = read_write;
                    sbadr_next = addr;
                    sbdat_to_peripheral_next = (read_write == `SBRW_WRITE) ?  write_data : 8'hxx;
                    busy_next = 1'b1;
                end else begin
                    state_next = `S_0;
                    sbrw_next = 1'bx;
                    sbadr_next = 8'hxx;
                    sbdat_to_peripheral_next = 8'hxx;
                    busy_next = 1'b0;
                end
                read_data_next = read_data;
                sbstb = 1'b0;
            end

            `S_1: begin
                state_next = `S_2;
                sbrw_next = sbrw;
                sbstb = 1'b1;
                sbadr_next = sbadr;
                sbdat_to_peripheral_next = sbdat_to_peripheral;
                read_data_next = read_data;
                busy_next = 1'b1;
            end

            `S_2: begin
                if (sback) begin
                    state_next = `S_0;
                    sbrw_next = 1'bx;
                    read_data_next = (sbrw == `SBRW_WRITE) ? 8'hxx : sbdat_from_peripheral;
                    busy_next = 1'b0;
                end else begin
                    state_next = `S_2;
                    sbrw_next = sbrw;
                    read_data_next = read_data;
                    busy_next = 1'b1;
                end
                sbstb = 1'b1;
                sbadr_next = sbadr;
                sbdat_to_peripheral_next = sbdat_to_peripheral;
            end
        endcase
    end

    always @(posedge clock) begin
        if (!reset) begin
            state <= state_next;
            busy <= busy_next;
            sbrw <= sbrw_next;
            sbadr <= sbadr_next;
            sbdat_to_peripheral <= sbdat_to_peripheral_next;
            read_data <= read_data_next;
        end else begin
            state <= `S_0;
            busy <= 1'b0;
            sbrw <= `SBRW_READ;
            sbadr <= 8'hxx;
            sbdat_to_peripheral <= 8'hxx;
            read_data <= 8'hxx;
        end
    end
endmodule


`define I2C_PERIPHERAL_DEVICE_ADDR (7'h23)
`define XFER_WIDTH (3)

//`define I2C_CR1_ADDR         4'b0001
`define I2C_CR1_ADDR         4'b1000
`define I2C_BRLSB_ADDR       4'b0010
`define I2C_BRMSB_ADDR       4'b0011
`define I2C_SADDR_ADDR       4'b0100
`define I2C_IRQEN_ADDR       4'b0101
`define I2C_FIFOTHRESH_ADDR  4'b0110
`define I2C_CMDR_ADDR        4'b0111
`define I2C_TXDR_ADDR        4'b1000
`define I2C_RXDR_ADDR        4'b1001
`define I2C_GCDR_ADDR        4'b1111
`define I2C_SR_ADDR          4'b1011
`define I2C_IRQ_ADDR         4'b1100

`define I2C_SR_BUSY_MASK     8'b0100_0000
`define I2C_SR_TRRDY_MASK    8'b0000_0100
`define I2C_SR_TROE_NACK_MASK 8'b0000_0010
/**
 * This module starts by setting up the i2c IP with static, predetermined register
 * settings, then follows the flowchart in Figure 7 of Lattice TN1276 to transmit a fixed sequence
 * of bytes over i2c.
 */
module i2c_sender(input                clock,
                  input                reset,

                  // i/o from/to hardened I2C ip.
                  input [7:0]          sbdat_from_peripheral,
                  input                sback,
                  input                i2c_irq,
                  input                i2c_wkup,

                  output               sbclk,
                  output               sbrw,
                  output               sbstb,
                  output     [7:0]     sbadr,
                  output     [7:0]     sbdat_to_peripheral,

                  output     [1:0]           expose_sbc_state,
                  output     [3:0]           expose_state);
    parameter [3:0] addr74 = 4'b0001;

    // State machine for managing "Lattice System Bus" transactions
    reg [7:0]     bus_controller_addr;
    reg [7:0]     bus_controller_write_data;
    reg           bus_controller_start_transaction;
    reg           bus_controller_read_write;

    wire                 bus_controller_ready;
    wire [7:0]           bus_controller_read_data;

    lattice_system_bus_controller sbc(.clock(clock),
                                      .reset(reset),

                                      .addr(bus_controller_addr),
                                      .write_data(bus_controller_write_data),
                                      .start_transaction(bus_controller_start_transaction),
                                      .read_write(bus_controller_read_write),

                                      .ready(bus_controller_ready),
                                      .read_data(bus_controller_read_data),

                                      .sbdat_from_peripheral(sbdat_from_peripheral),
                                      .sback(sback),
                                      .i2c_irq(i2c_irq),
                                      .i2c_wkup(i2c_wkup),

                                      .sbclk(sbclk),
                                      .sbrw(sbrw),
                                      .sbstb(sbstb),
                                      .sbadr(sbadr),
                                      .sbdat_to_peripheral(sbdat_to_peripheral),
                                      .expose_state(expose_sbc_state));

    localparam num_i2c_setup_registers = 5;
    reg [7:0] i2c_setup_data  [0:(num_i2c_setup_registers - 1)];
    reg [7:0] i2c_setup_addrs [0:(num_i2c_setup_registers - 1)];

    localparam num_i2c_xfers = 4;
    reg [23:0] i2c_xfers [0:(num_i2c_xfers - 1)];

`define max(a, b) ((a) > (b) ? (a) : (b))
    localparam ptr_len = $clog2(`max(num_i2c_setup_registers, num_i2c_xfers));

`define SENDER_STATE_INITIALIZE_IP             0
`define SENDER_STATE_I2C_TX_WRITE_TXDR         1
`define SENDER_STATE_I2C_TX_WRITE_CMDR         2
`define SENDER_STATE_I2C_TRRDY_WAIT            3
`define SENDER_STATE_I2C_STOP_WRITE_CMDR       4
`define SENDER_STATE_FINISHED                  5
`define SENDER_STATE_I2C_STOP_WRITE_CMDR_AFTER_NACK  6
`define SENDER_STATE_ERR                       7
`define SENDER_STATE_WAIT_I2C_READY            8

    reg [3:0] sender_state;
    reg [3:0] sender_state_next;
    reg [ptr_len - 1 : 0] data_ptr;
    reg [ptr_len - 1 : 0] data_ptr_next;
    reg [1:0] i2c_txn_counter;
    reg [1:0] i2c_txn_counter_next;

    assign expose_state = sender_state;
    always @* begin
        if (!reset) begin
            bus_controller_addr = 8'hxx;
            bus_controller_write_data = 8'hxx;
            bus_controller_read_write = 1'bx;
            bus_controller_start_transaction = 1'bx;
            data_ptr_next = 'hx;
            sender_state_next = 'hx;
            i2c_txn_counter_next = 'hx;
            case (sender_state)
                `SENDER_STATE_INITIALIZE_IP: begin
                    bus_controller_addr = i2c_setup_addrs[data_ptr];
                    bus_controller_write_data = i2c_setup_data[data_ptr];
                    bus_controller_read_write = 1'b1;
                    bus_controller_start_transaction = 1'b1;

                    if (bus_controller_ready) begin
                        if (data_ptr == num_i2c_setup_registers) begin
                            data_ptr_next = 'h0;
                            sender_state_next = `SENDER_STATE_WAIT_I2C_READY;
                        end else begin
                            data_ptr_next = data_ptr + 'h1;
                            sender_state_next = `SENDER_STATE_INITIALIZE_IP;
                        end
                    end else begin
                        data_ptr_next = data_ptr;
                        sender_state_next = `SENDER_STATE_INITIALIZE_IP;
                    end

                    i2c_txn_counter_next = 'h0;
                end

                // Poll until the i2c is ready.
                `SENDER_STATE_WAIT_I2C_READY: begin
                    bus_controller_addr = {addr74, `I2C_TXDR_ADDR};
                    bus_controller_write_data = 8'hxx;
                    bus_controller_read_write = 1'b0;
                    bus_controller_start_transaction = 1'b1;
                    data_ptr_next = data_ptr;
                    if (bus_controller_ready) begin
                        if (bus_controller_read_data & `I2C_SR_BUSY_MASK) begin
                            sender_state_next = `SENDER_STATE_I2C_TX_WRITE_TXDR;
                        end else begin
                            sender_state_next = `SENDER_STATE_WAIT_I2C_READY;
                        end
                    end else begin
                        sender_state_next = `SENDER_STATE_WAIT_I2C_READY;
                    end
                    i2c_txn_counter_next = i2c_txn_counter;
                end

                // Setup
                `SENDER_STATE_I2C_TX_WRITE_TXDR: begin
                    bus_controller_addr = {addr74, `I2C_TXDR_ADDR};
                    bus_controller_write_data = i2c_xfers[data_ptr][8 * i2c_txn_counter +: 8];
                    bus_controller_read_write = 1'b1;
                    bus_controller_start_transaction = 1'b1;
                    data_ptr_next = data_ptr;
                    sender_state_next = bus_controller_ready ? `SENDER_STATE_I2C_TX_WRITE_CMDR :
                                         `SENDER_STATE_I2C_TX_WRITE_TXDR;
                    i2c_txn_counter_next = i2c_txn_counter;
                end

                `SENDER_STATE_I2C_TX_WRITE_CMDR: begin
                    bus_controller_addr = {addr74, `I2C_CMDR_ADDR};
                    bus_controller_write_data = 8'b1001_0100;
                    bus_controller_read_write = 1'b1;
                    bus_controller_start_transaction = 1'b1;
                    data_ptr_next = data_ptr;
                    sender_state_next = bus_controller_ready ? `SENDER_STATE_I2C_TRRDY_WAIT :
                                         `SENDER_STATE_I2C_TX_WRITE_CMDR;
                    i2c_txn_counter_next = i2c_txn_counter;
                end

                // Poll until transaction is over.
                `SENDER_STATE_I2C_TRRDY_WAIT: begin
                    bus_controller_addr = {addr74, `I2C_SR_ADDR};
                    bus_controller_write_data = 8'hxx;
                    bus_controller_read_write = 1'b0;
                    bus_controller_start_transaction = 1'b1;
                    data_ptr_next = data_ptr;
                    if (bus_controller_ready) begin
                        if (!(bus_controller_read_data & `I2C_SR_BUSY_MASK)) begin
                            sender_state_next = `SENDER_STATE_ERR;
                            i2c_txn_counter_next = i2c_txn_counter;
                        end else if (bus_controller_read_data & `I2C_SR_TROE_NACK_MASK) begin
                            sender_state_next = `SENDER_STATE_I2C_STOP_WRITE_CMDR_AFTER_NACK;
                            i2c_txn_counter_next = i2c_txn_counter;
                        end else if (bus_controller_read_data & `I2C_SR_TRRDY_MASK) begin
                            sender_state_next = (i2c_txn_counter == 2) ?
                                                `SENDER_STATE_I2C_STOP_WRITE_CMDR :
                                                `SENDER_STATE_WAIT_I2C_READY;
                            i2c_txn_counter_next = (i2c_txn_counter == 2) ?
                                                   'h0 : (i2c_txn_counter + 'h1);
                        end else begin
                            sender_state_next = `SENDER_STATE_I2C_TRRDY_WAIT;
                            i2c_txn_counter_next = i2c_txn_counter;
                        end
                    end else begin
                        sender_state_next = `SENDER_STATE_I2C_TRRDY_WAIT;
                        i2c_txn_counter_next = i2c_txn_counter_next;
                    end
                end

                // Initiate stop sequence; advance
                `SENDER_STATE_I2C_STOP_WRITE_CMDR: begin
                    bus_controller_addr = {addr74, `I2C_CMDR_ADDR};
                    bus_controller_write_data = 8'h44;
                    bus_controller_read_write = 1'b1;
                    bus_controller_start_transaction = 1'b1;
                    if (bus_controller_ready) begin
                        if (data_ptr == (num_i2c_xfers - 1)) begin
                            sender_state_next = `SENDER_STATE_FINISHED;
                            data_ptr_next = 'hx;
                        end else begin
                            sender_state_next = `SENDER_STATE_WAIT_I2C_READY;
                            data_ptr_next = data_ptr + 'h1;
                        end
                    end else begin
                        sender_state_next = sender_state;
                        data_ptr_next = data_ptr;
                    end
                    i2c_txn_counter_next = i2c_txn_counter;
                end

                `SENDER_STATE_FINISHED: begin
                    bus_controller_addr = 8'hxx;
                    bus_controller_write_data = 8'hxx;
                    bus_controller_read_write = 1'b0;
                    bus_controller_start_transaction = 1'b0;
                    data_ptr_next = 'hx;
                    sender_state_next = `SENDER_STATE_FINISHED;
                    i2c_txn_counter_next = 'hx;
                end
            endcase
        end else begin // if (!reset)
            bus_controller_addr = 8'hxx;
            bus_controller_write_data = 8'hxx;
            bus_controller_read_write = 1'b0;
            bus_controller_start_transaction = 1'b0;
            data_ptr_next = {ptr_len{1'b0}};
            sender_state_next = `SENDER_STATE_INITIALIZE_IP;
            //sender_state_next = `SENDER_STATE_WAIT_I2C_READY;
            i2c_txn_counter_next = 2'h0;
        end
    end

    always @(posedge clock) begin
        sender_state <= sender_state_next;
        data_ptr <= data_ptr_next;
        i2c_txn_counter <= i2c_txn_counter_next;
    end

    // Test data
    initial begin : i2c_xfer_populate_data
        integer i;
        for (i = 0; i < 5; i = i + 1) i2c_xfers[i] = {i * i, i, 8'h46};
    end

    initial begin
        {i2c_setup_addrs[0], i2c_setup_data[0]} = {{addr74, `I2C_CR1_ADDR},      8'b1000_0000};
        {i2c_setup_addrs[1], i2c_setup_data[1]} = {{addr74, `I2C_BRLSB_ADDR},    8'd120};
        {i2c_setup_addrs[2], i2c_setup_data[2]} = {{addr74, `I2C_BRMSB_ADDR},    8'd000};
        {i2c_setup_addrs[3], i2c_setup_data[3]} = {{addr74, `I2C_BRMSB_ADDR},    8'd000};
        {i2c_setup_addrs[4], i2c_setup_data[4]} = {{addr74, `I2C_IRQEN_ADDR},    8'b0000_0110};
    end
endmodule
