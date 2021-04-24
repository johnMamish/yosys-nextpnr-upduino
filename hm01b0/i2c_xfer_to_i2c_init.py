data = []
with open("i2c_bytes.hex") as file:
    for line in file:
        if (not(line.startswith("//")) and (len(line) > 2)):
            data.append(int(line, 16))

trips = [list(tup) for tup in zip(data[0::3], data[1::3], data[2::3])]
padded = [[int("010100100", 2)] + [(x + (1 << 8)) for x in a] + [0] for a in trips]

for l in padded:
    print("{:03x} {:03x} {:03x} {:03x} {:03x}".format(l[0], l[1], l[2], l[3], l[4]))
