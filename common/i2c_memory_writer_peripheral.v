


`timescale 1ns/100ps

`define DEVICE_ADDRESS (8'hFE) //technically gotta check if last bit is R/W
                               //however, here, controller only ever sends data, so bit 0 = 0
`define EBR_ADDRESS_0 (8'h00)
`define EBR_ADDRESS_1 (8'h01)

`define IDLE (2'b00) //wait here. if start, goto dev_adr.
`define DEV_ADR (2'b01) //wait here while reading in, counter++. if data=device_address, ack and goto ebr_adr. else, nack and goto idle. if start, restart dev_adr. if stop, goto idle.
`define EBR_ADR (2'b10) //wait here while reading in, counter++. if in=ebr_adress_0or1, ack and goto fill. else, nack and goto idle. if start, goto dev_adr. if stop, goto idle.
`define FILL (2'b11) //wait here while reading in, counter++. write data to ebr_adr each time counter = 8 then reset counter. if start, goto dev_adr. if stop, goto idle.

/**
 * outputs:
 *     write_active     High when the peripheral is in the FILL state. Can be used for
 *                      resetting external logic.
 */
module i2c_memory_writer_peripheral(input            clock,
                                    input            reset,

                                    input            copi_scl,
                                    input            copi_sda,
                                    output           cipo_scl, //not doing any stretching
                                    output reg       cipo_sda,

                                    output reg       write_active,
                                    output reg       ebr_select,
                                    output reg       ebr_wren,
                                    output reg [7:0] ebr_data_out,

                                    output [1:0]      state_out,
                                    output [3:0]      counter_out);
    assign cipo_scl = 1'b1;
    reg cipo_sda_next;
    reg ebr_select_next;
    reg ebr_wren_next;
    reg [7:0] ebr_data_out_next;

    reg [1:0] state;
    reg [1:0] state_next;
    reg [3:0] counter;
    reg [3:0] counter_next;
    reg sda; //sample copi_sda
    reg sda_next;
    reg scl; //sample copi_scl
    reg scl_next;
    reg write_active_next;

    assign state_out = state;
    assign counter_out = counter;

    always @(posedge clock) begin
        cipo_sda <= cipo_sda_next;
        ebr_select <= ebr_select_next;
        ebr_wren <= ebr_wren_next;
        ebr_data_out <= ebr_data_out_next;

        state <= state_next;
        counter <= counter_next;

        sda <= sda_next;
        scl <= scl_next;

        write_active <= write_active_next;
    end


    always @* begin
        //defaults:
        cipo_sda_next = cipo_sda;
        ebr_select_next = ebr_select;
        ebr_wren_next = 1'b0;
        ebr_data_out_next = ebr_data_out;

        state_next = state;
        counter_next = counter;

        sda_next = copi_sda;
        scl_next = copi_scl;

        write_active_next = 1'b0;

        if (reset) begin
            cipo_sda_next = 1'b1;
            ebr_select_next = 1'bx;
            ebr_data_out_next = 8'hxx;

            state_next = `IDLE;
            counter_next = 4'h0;
            write_active_next = 1'b0;
        end else if (scl_next == 1'b1 && scl == 1'b1 && sda_next == 1'b0 && sda == 1'b1) begin
            // handle start condition: move to the DEV_ADR state
            cipo_sda_next = 1'b1;
            ebr_select_next = 1'bx;
            ebr_data_out_next = 8'h00; //00 bc < | data_out> used

            state_next = `DEV_ADR;
            counter_next = 4'h0;
        end else if (scl_next == 1'b1 && scl == 1'b1 && sda_next == 1'b1 && sda == 1'b0) begin
            // handle stop condition
            cipo_sda_next = 1'b1;
            ebr_select_next = 1'bx;
            ebr_data_out_next = 8'hxx;

            state_next = `IDLE;
            counter_next = 4'h0;
        end else begin
            case (state)
                `IDLE: begin
                    // all signals retain their default values until a start condition is detected.
                    write_active_next = 1'b0;
                end

                `DEV_ADR: begin
                    write_active_next = 1'b0;

                    if (scl_next == 1'b1 && scl == 1'b0) begin
                        //posedge scl
                        if (counter <= 4'h7) begin
                            // if we're not in the ACK stage, clock in a new bit.
                            ebr_data_out_next = ebr_data_out | ({sda_next,7'b0000000} >> counter);
                        end

                        // always increment the counter on the posedge of scl
                        counter_next = counter + 4'h1;
                    end else if (scl_next == 1'b0 && scl == 1'b1) begin
                        //negedge scl
                        if (counter == 4'h8) begin
                            if (ebr_data_out == `DEVICE_ADDRESS) begin
                                // If we're on the falling edge of SCL on the 8th bit, we should
                                // pull SDA down for the ack if the byte we read in matches the
                                // device address.
                                cipo_sda_next = 1'b0;
                            end else begin
                                // The device address doesn't match, go back to the idle state and
                                state_next = `IDLE;
                                ebr_data_out_next = 8'hxx;
                                counter_next = 4'h0;
                            end
                        end else if (counter == 4'h9) begin
                            // Falling edge of SCL after ACK complete.
                            cipo_sda_next = 1'b1;
                            state_next = `EBR_ADR;
                            ebr_data_out_next = 8'h00;
                            counter_next = 4'h0;
                        end else if (counter >= 4'hA) begin //this shouldn't happen
                            state_next = `IDLE;
                            ebr_data_out_next = 8'hxx;
                            counter_next = 4'h0;
                        end
                    end
                end

                `EBR_ADR: begin
                    write_active_next = 1'b0;

                    //posedge scl
                    if (scl_next == 1'b1 && scl == 1'b0) begin
                        if (counter <= 4'h7) begin
                            ebr_data_out_next = ebr_data_out | ({sda_next,7'b0000000} >> counter);
                        end
                        counter_next = counter + 4'h1;
                    //negedge scl
                    end else if (scl_next == 1'b0 && scl == 1'b1) begin
                        //begin ack
                        if (counter == 4'h8) begin
                            if (ebr_data_out == `EBR_ADDRESS_0) begin
                                cipo_sda_next = 1'b0;
                                ebr_select_next = 1'b0;
                            end else if (ebr_data_out == `EBR_ADDRESS_1) begin
                                cipo_sda_next = 1'b0;
                                ebr_select_next = 1'b1;
                            end else begin
                                state_next = `IDLE;
                                ebr_data_out_next = 8'hxx;
                                counter_next = 4'h0;
                            end
                        //end ack
                        end else if (counter == 4'h9) begin
                            cipo_sda_next = 1'b1;
                            state_next = `FILL;
                            ebr_data_out_next = 8'h00;
                            counter_next = 4'h0;
                        end else if (counter >= 4'hA) begin //this shouldn't happen
                            state_next = `IDLE;
                            ebr_data_out_next = 8'hxx;
                            counter_next = 4'h0;
                        end
                    end
                end

                `FILL: begin
                    write_active_next = 1'b1;

                    //posedge scl
                    if (scl_next == 1'b1 && scl == 1'b0) begin
                        if (counter <= 4'h7) begin
                            ebr_data_out_next = ebr_data_out | ({sda_next,7'b0000000} >> counter);
                        end
                        counter_next = counter + 4'h1;
                    //negedge scl
                    end else if (scl_next == 1'b0 && scl == 1'b1) begin
                        //begin ack
                        if (counter == 4'h8) begin
                            cipo_sda_next = 1'b0;
                            ebr_wren_next = 1'b1;
                        end else if (counter == 4'h9) begin
                            //end ack
                            cipo_sda_next = 1'b1;
                            ebr_data_out_next = 8'h00;
                            counter_next = 4'h0;
                        end else if (counter >= 4'hA) begin //this shouldn't happen
                            state_next = `IDLE;
                            ebr_data_out_next = 8'hxx;
                            counter_next = 4'h0;
                        end
                    end
                end
            endcase
        end
    end
endmodule
