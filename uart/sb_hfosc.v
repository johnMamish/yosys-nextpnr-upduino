`timescale 1ns/100ps

module SB_HFOSC(input CLKHFPU,
	        input CLKHFEN,
		output reg CLKHF);
    always begin
        CLKHF = 1'b0;
        #10.4166666667;
        CLKHF = 1'b1;
        #10.4166666666;
    end
endmodule
