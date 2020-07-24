#!/usr/bin/python3

# This script takes a decoded Saleae logic parallel port trace and tries to convert it to an image.
#
# We assume that bit 7 holds vsync and bit 6 holds hsync. Bits 0 - 3 hold pixel data.

# example file portion:
# 0.000055850000000,0x00CF
# 0.000055940000000,0x00C2
# 0.000056040000000,0x00C8
# 0.000056140000000,0x00C2
# 0.000056230000000,0x00C4
# 0.000056330000000,0x0080
# 0.000056430000000,0x0080
# 0.000056530000000,0x0080
# 0.000056620000000,0x0080
# 0.000056720000000,0x0080


# M is a string.
# To map the nybble back to itself, pass in "3210"
# To reverse the nybble, pass in "0123"
def permute_nybble(nybble, m):
    out = np.uint8(0)
    mask = (1 << 3)
    for ch in m:
        if (nybble & mask):
            out = out | (1 << int(ch))
        mask = mask >> 1
    return out

def is_valid_decimal_number(s):
    try:
        float(s)
    except ValueError:
        return False
    else:
        return True

# De-mosaics a numpy 2d array
# returns another 2d numpy array, in grayscale
def demosaic(arr):
    red = np.zeros((324, 324))
    green = np.zeros((324, 324))
    blue = np.zeros((324, 324))

    filterquart1 = np.array([[.25, .00, .25],
                             [.00, .00, .00],
                             [.25, .00, .25]])
    filterquart2 = np.array([[.00, .25, .00],
                             [.25, .00, .25],
                             [.00, .25, .00]])
    filterfifths = np.array([[.20, .00, .20],
                             [.00, .20, .00],
                             [.20, .00, .20]])
    filterone    = np.array([[.00, .00, .00],
                             [.00, 1.0, .00],
                             [.00, .00, .00]])
    filterupdown = np.array([[.00, .50, .00],
                             [.00, .00, .00],
                             [.00, .50, .00]])
    filterlr     = np.array([[.00, .00, .00],
                             [.50, .00, .50],
                             [.00, .00, .00]])
    for y in range(2, 323):
        for x in range(2, 323):
            if (((x % 2) == 0) and ((y % 2) == 0)):
                #blue
                red[y][x]  = sum(sum(arr[y-1:y+2,x-1:x+2] * filterquart1));
                blue[y][x] = sum(sum(arr[y-1:y+2,x-1:x+2] * filterone));
                green[y][x] = sum(sum(arr[y-1:y+2,x-1:x+2] * filterquart2));
            elif((((x % 2) == 1) and ((y % 2) == 0))):
                #green1
                red[y][x]  = sum(sum(arr[y-1:y+2,x-1:x+2] * filterupdown));
                blue[y][x] = sum(sum(arr[y-1:y+2,x-1:x+2] * filterlr));
                green[y][x] = sum(sum(arr[y-1:y+2,x-1:x+2] * filterfifths));
            elif((((x % 2) == 0) and ((y % 2) == 1))):
                #green2
                red[y][x]  = sum(sum(arr[y-1:y+2,x-1:x+2] * filterlr));
                blue[y][x] = sum(sum(arr[y-1:y+2,x-1:x+2] * filterupdown));
                green[y][x] = sum(sum(arr[y-1:y+2,x-1:x+2] * filterfifths));
            else:
                #red
                red[y][x]  = sum(sum(arr[y-1:y+2,x-1:x+2] * filterone));
                blue[y][x] = sum(sum(arr[y-1:y+2,x-1:x+2] * filterquart1));
                green[y][x] = sum(sum(arr[y-1:y+2,x-1:x+2] * filterquart2));

    return np.dstack((red, green, blue)).astype(np.uint8)
    #return red * 0.299 + green * 0.587 + blue * 0.114
    #return red + green + blue
    #return red

def file_to_np2d(filename):
    # read in image
    readbytes = []
    times = []
    with open(filename) as csvfile:
        reader = csv.reader(csvfile);
        for row in reader:
            if (is_valid_decimal_number(row[0])):
                readbytes.append(int(row[1], 16))
                times.append(float(row[0]))
    # detect rising edge of vsync
    posedge_index = -1
    for i in range(len(readbytes) - 1):
        if ((readbytes[i + 1] & (1 << 7)) and not (readbytes[i] & (1 << 7))):
            posedge_index = i + 1
            break
    if (posedge_index == -1):
        print("no posedge of vsync found")
        quit(-1)
    # detect falling edge of vsync
    negedge_index = -1;
    for i in range(posedge_index, len(readbytes) - 1):
        if ((readbytes[i] & (1 << 7)) and not (readbytes[i + 1] & (1 << 7))):
            negedge_index = i + 1;
            break
    if (negedge_index == -1):
        print("no negedge of vsync found")
        quit(-1)
    print("vsync posedge at index %i and time %f"%(posedge_index, times[posedge_index]))
    print("vsync negedge at index %i and time %f"%(negedge_index, times[negedge_index]))
    # turn all of the pixels into bytes. Based on the Saleae logic traces, it looks like the image
    # is actually 324x324
    img = np.zeros((325, 325), dtype=np.uint8)
    nybble_index = 1
    pixx = 0
    pixy = 0
    print(negedge_index)
    for i in range(posedge_index, negedge_index):
        # Only interpret data if hsync is high
        if ((readbytes[i] & (1 << 6))) :
            img[pixy][pixx] = img[pixy][pixx] | (permute_nybble((readbytes[i] & 15), "2310") << (nybble_index * 4))
            nybble_index = ((nybble_index - 1) % 2)
            if (nybble_index == 1):
                pixx = pixx + 1

        # Increment vertical index on rising edge of hsync
        if (not (readbytes[i] & (1 << 6)) and (readbytes[i + 1] & (1 << 6)))  :
            print("row %i"%(pixy))
            nybble_index = 1
            pixx = 0
            pixy = pixy + 1
    return img

import numpy as np
import csv
from PIL import Image
import PIL
import sys
if __name__ == "__main__":
    if (len(sys.argv) != 3):
        print("usage: %s <input text file> <output pnm file>"%(sys.argv[0]))
        quit(-1)

    img = file_to_np2d(sys.argv[1])
    # In some of the test cases, I found that the image needs to be shifted to the right 1 pixel.
    imggray = demosaic(img[1:,:])
    #imggray = demosaic(img)
    Image.fromarray(img, "L").show()
    Image.fromarray(imggray).show()
