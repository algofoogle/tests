nes02
=====

This is where I will just do a bunch of tests on ca65, to learn it and figure out how to
make it do what I want.

nes02/1
-------

This just demonstrates how to assemble/link to a specific binary image, with basic control
over addressing and labels.

nes02/2
-------

This shows how to create a minimum 'valid' `.nes` (iNES) file, with a basic template for
how to define the extents of a simple PRG ROM (program) and CHR ROM (pattern table).
Though it assembles to a valid `.nes`, it has nothing in it -- i.e. no code -- and hence
is *not* a vaild *program*.

nes02/3
-------

This takes `nes02/2` a step further to a tiny NES program that actually runs. It adds
a valid interrupt vector table at the top of the PRG ROM (i.e. $FFF4-$FFFF, though
really only $FFFA-$FFFF is used), which means the 6502 will have a valid 'reset address'
that points to the start of the program. In the same way it also defines (empty) ISRs for
NMI and IRQ/BRK.

All this program does is send a few commands to the APU that start it playing a square wave,
and then it hangs by entering a do-nothing endless loop.

nes02/4
-------

This extends `nes02/4` to define a bit more of the CPU's memory map, and hence uses
RAM (in the zero page) to set up a basic delay counter that lets us switch the APU's Pulse
generator between two different frequencies, essentially creating a basic phone ring effect.

