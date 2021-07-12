### yosys + nextpnr example projects for iCE40 upduino

These folders have example projects that can be synthesized for the iCE40 fpga using an entirely open-source toolchain. Each subfolder can be compiled with 'make', which produces a ??? file. This file can be deployed to an iCE40 fpga board with iceprog. These projects are all intended for the upduino board.

To compile these projects, you need the following programs installed:
  * [yosys](https://github.com/YosysHQ/yosys) for synthesis
  * [nextpnr](https://github.com/YosysHQ/nextpnr) for place-and-route
  * [icestorm](https://github.com/YosysHQ/icestorm) for place-and-route and for programming.

Synthesized designs result in a .bin file which is programmed by running
    `sudo iceprog ./<design>.bin`

I'm having trouble finding solid documentation for the Physical Constraint File (.pcf) commands. [This page in the nextpnr repo](https://github.com/YosysHQ/nextpnr/blob/master/docs/ice40.md) has a little info, but it doesn't say how unused pins are configured.

### Building
Projects are built with the following 2 steps:
  * Synthesize with Yosys:<br/>
This step requires one more more verilog files, one of which contains your top-level module, and a `yosys` script. Make sure that the `yosys` script identifies which verilog module should be the top-level one. You can check out some of the existing `yosys` scripts for examples (like [this one](https://github.com/johnMamish/yosys-nextpnr-upduino/blob/master/milliLearn/uart/uart.yosys)).<br/>
Once you have your verilog files and yosys script ready, run `yosys -s <yourscript>.yosys`

  * Run place-and-route with nextpnr:<br/>
This step takes the output of the synthesis step (a `.json` file) and generates a `.bin` file which can be flashed to an FPGA using the `nextpnr-ice40` command. Check out one of the [example Makefiles](https://github.com/johnMamish/yosys-nextpnr-upduino/blob/master/milliLearn/uart/Makefile#L5) to see how to invoke this command. You also need a pin-constraint file (`.pcf`) so the place-and-route tool knows which I/O pins correspond to which signals in the top-level module. For the "milliLearn" dev board, a default `pcf` file can be found [here](https://github.com/johnMamish/milliLearn-boards/blob/master/ice40/rev1.pcf).

The bare minimum files for each project are
  * A top-level `.v` file. Its toplevel module needs to be specified in the yosys script
  * A `pcf` file so the place-and-route tool knows which GPIO pins correspond to which signals in your design.
  * A `yosys` script
  * You probably want a makefile too, but that's not strictly necessary.
