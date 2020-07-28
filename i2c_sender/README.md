### This example is presently non-functional.
The documentation for the iCE40 UltraPlus 5k hardened i2c block is wrong [[1]](https://github.com/YosysHQ/icestorm/issues/174), and I don't have the time to wrassle it right now.

### This subproject has an example implementation of a very simple i2c [~~master~~](https://web.archive.org/web/20200629195321/https://hackaday.com/2020/06/29/updating-the-language-of-spi-pin-labels-to-remove-casual-references-to-slavery/) controller device.

All this verilog can do is send a list of fixed-width byte sequences to an i2c peripheral device. It is useful for configuring i2c peripheral devices at startup.

It uses the iCE40 hardened i2c IP directly.