Chromp
======

# Overview

"Chromp" (pronounced 'kromp') is a utility to take a PNG and convert it to a NES
CHR-ROM format of some kind... Be it assembly code, or a raw binary file.

# Usage

First, run `bundle` to install the gems needed by `chromp.rb`.

Then, you can run `./chromp.rb` as a test, to see this output:

    Usage: ./chromp.rb [-8] [-m] sourceimage.png targetrom.bin
    Where:
      -8               = Pad the file out to 8KiB (i.e. add 256 extra blank tiles, to make up the standard CHR-ROM size).
      -m               = The last line of the source PNG defines the 'colour map'.
      sourceimage.png  = Source PNG file, 128x128 pixels.
      targetrom.bin    = CHR-ROM binary file to write; will be 4KiB or 8KiB depending on -8 switch.

So, to make a CHR ROM:

    ./chromp.rb -m ASCII-05m.png anton05.chr

To explain:

*   The input file should be a PNG that is 128x129 pixels.
*   The last line uses its first 4 pixels to define the colour indices.
    For example, in that last line, if the first pixel (at X=0) is `#FF9900`, then any pixel
    of that colour in the rest of the image will get index 0.
*   A pixel of any other colour defaults to index 0. This lets us have (say) a grid or other
    markers in there, for our own purposes, which are invisible to the reader.
*   The output file format is a NES CHR ROM.


# OLD usage information

NOTE: I think this still provides a little bit of an explanation of how this works,
but is no longer accurate because `chromp` now can generate CHR ROMs directly.

>   For now, chromp can only read a PNG (that is 16x16 tiles of 8x8 each, i.e. 128x128 pixels)
>   and interpret it to store a set of `NesChar` objects in memory, representing each tile.
>   All of these are contained by a `NesCharRom` object, with an `ascii_render` method that
>   can render out an ASCII string as proof that the image decoder is working.
>   
>   I need to get it to produce useful files, as soon as I understand the NES CHR-ROM binary format.

NOTE: [`ASCII-02m.gal`](ASCII-02m.gal) was created with
[GraphicsGale](https://graphicsgale.com/us/).
