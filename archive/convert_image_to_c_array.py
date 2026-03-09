#!/usr/bin/python

from PIL import Image

def set_bit(value, bit):
    return value | (1<<bit)

def clear_bit(value, bit):
    return value & ~(1<<bit)

filename = "RgbMatrixDrawingTool/matrix.png"

grayscale = True
#size = (32, 32)
#size = (112, 112)
size = (128, 128)

# Bitmap example w/graphics prims
image = Image.open(filename)
image.load()
image = image.resize(size, resample=Image.ANTIALIAS)

print("#define IMAGE_WIDTH {}".format(image.size[0]))
print("#define IMAGE_HEIGHT {}".format(image.size[1]))
if grayscale:
    print("static const uint8_t U8X8_PROGMEM IMAGE[] = {")
    image = image.convert('1')
    for y in range(0,image.size[1]):
        print("  ", end="")
        for x in range(0, image.size[0], 8):
            color = 0
            for k in range(8):
                if (image.getpixel((x+k, y)) > 0):
                    color = set_bit(color, k)
                else:
                    color = clear_bit(color, k)
            print(hex(color), end=", ")
        print()
    print("};")
else:
    print("const int16_t PROGMEM IMAGE[] = {")
    for y in range(0,image.size[1]):
        print("  ", end="")
        for x in range(0,image.size[0]):
            r, g, b, a = image.getpixel((x, y))
            r = int(r / 8)
            g = int(g / 4)
            b = int(b / 8)
            color = 2048*r + 32*g + b
            color = 65535 - color
            print(hex(color), end=", ")
        print()
    print("};")
