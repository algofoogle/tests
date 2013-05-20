Chromp
======

Overview
--------

"Chromp" (pronounced 'kromp') is a utility to take a PNG and convert it to a NES
CHR-ROM format of some kind... Be it assembly code, or a raw binary file.

Usage
-----

For now, chromp can only read a PNG (that is 16x16 tiles of 8x8 each, i.e. 128x128 pixels)
and interpret it to store a set of `NesChar` objects in memory, representing each tile.
All of these are contained by a `NesCharRom` object, with an `ascii_render` method that
can render out an ASCII string as proof that the image decoder is working.

I need to get it to produce useful files, as soon as I understand the NES CHR-ROM binary format.

