# yosys + nextpnr example projects

These folders have example projects that can be synthesized for the iCE40 fpga using an entirely open-source toolchain. Each subfolder can be compiled with 'make', which produces a ??? file. This file can be deployed to an iCE40 fpga board with iceprog. These projects are all intended for the upduino board.

To compile these projects, you need the following programs installed:
  * [yosys](https://github.com/YosysHQ/yosys) for synthesis
  * [nextpnr](https://github.com/YosysHQ/nextpnr) for place-and-route
  * [icestorm](https://github.com/YosysHQ/icestorm) for place-and-route and for programming.
