#!/usr/bin/env python3

import pygame
import serial
import io
import numpy as np

width = 320
height = 240

screen = pygame.display.set_mode((width, height))
pygame.display.flip()

# ser = serial.Serial('/dev/ttyUSB0', 460800 * 2, timeout=0, parity=serial.PARITY_EVEN)
ser = serial.Serial('/dev/ttyUSB0', 2000000, timeout=0, parity=serial.PARITY_EVEN)
running = True
image = [None] * (width * height)
imagestr = b""

while running:
    # Read serial data
    while ser.in_waiting:  # Or: while ser.inWaiting():
        foo = ser.readline()
        #print(foo)
        imagestr += foo

    if (imagestr[-4:] == b"\xf0\x0f\xba\x11"):
        # data just before "magic end sequence" is debug messages.
        debug_msg_len = len(imagestr) - (width * height) - 4
        if (debug_msg_len >= 0):
            debug_msg = str(imagestr[-(debug_msg_len + 4): -4], 'utf-8', errors="ignore")
        else:
            debug_msg = ""
            debug_msg_len = 0
        print(debug_msg)
        arr = imagestr[:-(debug_msg_len + 4)]
        imagestr = b""
        if (len(arr) == (width * height)) :
            x = 0
            y = 0
            out = demosaic(arr)
            print(out.tobytes()[1500:1510])
            image = pygame.image.frombuffer(out.tobytes(), (width, height), "RGB")
            screen.blit(image, (0, 0))

            pygame.display.update()

    # check if x was pressed to close window.
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False


pygame.quit()
