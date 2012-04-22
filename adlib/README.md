Anton's Simple AdLib Test
=========================

Introduction
------------

I wanted to tinker with FM music synthesis and have been a bit
obsessed with classic PC videogames, which lead me to the AdLib
soundcard: http://www.shipbrook.net/jeff/sb.html

The AdLib card uses the YM3812 (aka OPL2) chip, and an easy way
to emulate this on a modern PC is with DOSBox.

The actual program that this code builds is `asalt.com`
(i.e. Anton's Simple AdLib Test).


Building
--------

For whatever reason -- maybe for that genuine retro feel -- I
decided to code this test in x86 assembly, as a 16-bit DOS app.

To build this, you'll need NASM installed. You can run `b.cmd`
just to build, or run `br.cmd` to build and run -- though you'll
probably find that it doesn't run properly unless it's under
DOSBox.


Examination
-----------

This "project" is a bit clumsy, like all of my tests: it's a
learning exercise and not meant to be used seriously or as an
exemplary bit of code.

These are the soure files for this project:

```
asalt.s    - main code
delay.s    - roughly-millisecond-accurate delay routine based on IRQ 8
macros.s   - various helpers for easier coding
print.s    - various screen output routines
```
