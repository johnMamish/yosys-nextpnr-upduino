cursor dimensions in terminal: 11x21
4 levels of grayscale... Let's interpolate 4 pixels horizontally and 8 pixels vertically. This
means that we'll have (((320 * 240) / (4 * 8)) + (2 * (240 / 8)) = 2460 ascii chars per frame (including \r\n).

The hm01b0 is running at 40 frames per second, so we'd need to have a baud rate of 885,600bps to keep up.


Lattice doesn't provide any documenation about the pinout for the connection from the hm01b0 bottom board to the vision + microphone top board. This is what I've figured out by using a saleae logic analyzer.

| GPIO # | Presumed function |
|--------|-------------------|
| 3      | sda to hm01b0     |
| 4      | scl to hm01b0     |
| 11     | a ~24MHz clock that's only active for the first 30 milliseconds? This might be a clock that's needed by the hm01b0 for startup until its internal oscillator kicks in.|
| 44     | hm01b0 hsync out  |
| 6      | hm01b0 vsync out  |
| 19     | hm01b0 pixclk out?  ~10.33 MHz |
| 21     | pix[0]            |
| 12     | pix[1]            |
| 37     | pix[2]            |
| 31     | pix[3]            |
|        |                   |
| 9      | nothing?          |
| 18     | nothing?          |
| 13     | nothing?          |
| 28     | active-high / active-hi-z led  |
| 38     | active-high / active-hi-z led  |
| 42     | active-high / active-hi-z led  |
| 35     | active-high / active-hi-z led  |
| 43     | active-high / active-hi-z led  |
| 34     | active-high / active-hi-z led  |