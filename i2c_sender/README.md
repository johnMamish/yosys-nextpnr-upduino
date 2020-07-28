### This subproject has an example implementation of a very simple i2c [~~master~~](https://web.archive.org/web/20200629195321/https://hackaday.com/2020/06/29/updating-the-language-of-spi-pin-labels-to-remove-casual-references-to-slavery/) controller device.

All this verilog can do is send a list of fixed-width byte sequences to an i2c peripheral device. It is useful for configuring i2c peripheral devices at startup.

It uses the iCE40 hardened i2c IP directly.