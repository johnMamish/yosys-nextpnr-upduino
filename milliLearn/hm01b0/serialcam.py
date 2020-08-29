#!/usr/bin/env python3

import pygame
import serial
import io
import numpy as np

width = int(320 / 2)
height = int(240 / 2)

screen = pygame.display.set_mode((width * 4, height * 4))
pygame.display.flip()

# ser = serial.Serial('/dev/ttyUSB0', 460800 * 2, timeout=0, parity=serial.PARITY_EVEN)
ser = serial.Serial('/dev/ttyUSB0', 2000000, timeout=0, parity=serial.PARITY_NONE)
running = True
image = [None] * (width * height)
imagestr = b""

# demosiac
# param: bytestring
def demosaic(data):
    arr = np.array(bytearray(data)).reshape(height, width).astype(int)
    out = np.zeros((int(height), int(width)), dtype=('<u1', 3))

    for y in range(1, height - 1):
        for x in range(1, width - 1):
            # pixel color
            red = arr[y][x]
            green = arr[y][x]
            blue = arr[y][x]

            out[y][x] = (int(red), int(green), int(blue))


    return out

while running:
    # Read serial data
    while ser.in_waiting:  # Or: while ser.inWaiting():
        foo = ser.read()
        #print(foo)
        imagestr += foo
        #print(len(imagestr))
        if (imagestr[-4:] == b"\xf0\x0f\xba\x11"):
            break

    if (imagestr[-4:] == b"\xf0\x0f\xba\x11"):
        # data just before "magic end sequence" is debug messages.
        print("a");
        debug_msg_len = len(imagestr) - (width * height) - 4
        if (debug_msg_len >= 0):
            debug_msg = str(imagestr[-(debug_msg_len + 4): -4], 'utf-8', errors="ignore")
        else:
            debug_msg = ""
            debug_msg_len = 0
        print(debug_msg)
        arr = imagestr[:-(debug_msg_len + 4)]
        imagestr = b""
        print(len(arr))
        if (len(arr) == (width * height)) :
            x = 0
            y = 0
            out = demosaic(arr)
            #print(arr.tobytes()[1500:1510])
            image = pygame.image.frombuffer(out.tobytes(), (width, height), "RGB")
            image = pygame.transform.scale(image, (width * 4, height * 4))
            screen.blit(image, (0, 0))

            pygame.display.update()

    # check if x was pressed to close window.
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False


pygame.quit()
