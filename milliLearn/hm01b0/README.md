After plugging in the milliLearn board with the appropriate bitstream flashed, you should be able to run "sudo python3 serialcam.py" to open a serial port at 2,000,000 baud and display an image in a GUI window.

The board should have an LED blinking at about 2 Hz showing when it has captured a new frame.

Remember that after running iceprog, you need to disconnect and reconnect the USB cable
