#!/usr/bin/env python3

import pygame
import numpy as np
import serial
import io
from PIL import Image

import re
[m.start() for m in re.finditer('test', 'test test test test')]
#[0, 5, 10, 15]

import time

width = 320
height = 240

vstretch = 2
hstretch = 2

pygame.init()
pygame.display.set_caption(' ')
screen = pygame.display.set_mode((width * hstretch, height * vstretch))
pygame.display.flip()

# ser = serial.Serial('/dev/ttyUSB0', 460800 * 2, timeout=0, parity=serial.PARITY_EVEN)
ser = serial.Serial('/dev/ttyUSB0', 2000000, timeout=0, parity=serial.PARITY_NONE)
running = True
image = [None] * (width * height)
imagestr = b""

millis_prev = int(round(time.time() * 1000))

jpeg_header = b""
with open("./jpeg_header.bin", mode="rb") as f:
    jpeg_header = f.read()

while running:
    # Read serial data
    eoi_index = -1
    while ser.in_waiting:  # Or: while ser.inWaiting():
        foo = ser.read(ser.inWaiting())
        imagestr += foo

        eoi_index = imagestr[-(len(foo) + 1):].find(b'\xff\xd9')

        if (eoi_index != -1):
            eoi_index = imagestr.find(b'\xff\xd9')
            break

    #delimiters = [m.start() for m in re.finditer(b"\xff\xd9", imagestr)]
    #if (imagestr[-2:] == b"\xff\xd9"):
    if (eoi_index != -1):
        try:
            # add header info
            mostrecent = imagestr[0:eoi_index+2];
            image = pygame.image.load(io.BytesIO(jpeg_header + mostrecent))
            image = pygame.transform.scale(image, (width * hstretch, height * vstretch))
            screen.blit(image, (0, 0))
            pygame.display.update()

            #print(str(len(jpeg_header + mostrecent)) + " bytes")
            millis = int(round(time.time() * 1000))
            print((1000 / (millis - millis_prev)), end='\r')
            millis_prev = millis

        except OSError as e:
            print(e)
            print(' '.join('{:02x}'.format(x) for x in imagestr[0:127]))

        imagestr = imagestr[eoi_index + 2:]

    # check if x was pressed to close window.
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False


pygame.quit()
