/**
 * This testbench doesn't have a model of the Lattice IP attached to it. It's just for checking the
 * Lattice System Bus Interface state machine.
 */

`timescale 1ns/100ps

`define HALF_PERIOD 500

module i2c_sender_backend_tb();
    reg clock;
    reg reset;
    reg bus_ack_sim;

    wire [7:0] sbdat_from_peripheral;
    wire sback;

    wire sbclk;
    wire sbrw;
    wire sbstb;
    wire [7:0] sbadr;
    wire [7:0] sbdat_to_peripheral;

    i2c_sender sender(.clock(clock),
                      .reset(reset),
                      .sbdat_from_peripheral(8'h00),
                      .sback(bus_ack_sim),
                      .i2c_irq(1'bz),
                      .i2c_wkup(1'bz),

                      .sbclk(sbclk),
                      .sbrw(sbrw),
                      .sbstb(sbstb),
                      .sbadr(sbadr),
                      .sbdat_to_peripheral(sbdat_to_peripheral));

    always begin #`HALF_PERIOD clock = (clock === 1'b0); end

    always @* begin
        bus_ack_sim = #200 (sender.sbc.state == 2);
    end

    initial begin : main
        integer i;
        $dumpfile("i2c_sender_backend_tb.vcd");
        $dumpvars(0, i2c_sender_backend_tb);

        reset = 1'b1;
        @(posedge clock);
        @(posedge clock);
        reset =  #1 1'b0;

        for (i = 0; i < 500; i = i + 1) @(posedge clock);

        $finish;
    end
endmodule
