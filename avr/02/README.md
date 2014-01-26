# `tests/avr/02`



## What is this?

This is my 2nd example on Atmel AVR assembly language, demonstrating
very basic cycle-counting timing. The intent is to predict the timing
of each instruction, and prove both an understanding of how it works,
and how fast the MCU clock is running.

It is intended for an ATtiny13A, but should work
on any larger ATtiny, including ATtiny25, ATtiny45, and ATtiny85 --
default clocks may differ on some devices.



## What does it do?

This program simply toggles pins PB4..0 of the ATtiny13A at different rates.
A binary counter does the hard work, causing one pin to toggle at half the
rate of the next:

| Bit | Pin | Rate        |
|---
| PB0 | 5   | Ref         |
| PB1 | 6   | Ref/2       |
| PB2 | 7   | Ref/4       |
| PB3 | 2   | Ref/8       |
| PB4 | 3   | Ref/16      |

PB0 ("Ref") is the fastest. Its actual rate is dependent on the system clock,
and needs to be predicted based on the no. of CPU cycles required by the loop
that changes the pin states.



## How does it work?

From power-on:

1.	PB5..0 are configured to be outputs, though PB5 is unused because it is
	configured (by fuse bits) as External `/RESET`.

2.	Register `R16` is loaded with `0`, and written out to `PORTB`.

3.	In a loop, `R16` is incremented and written out to `PORTB` endlessly.

4.	The net effect is that bits in R16 toggle at a constant rate (where PB1
	toggles at half the rate of PB0; PB2 at half the rate of PB1; and so-on).
	Hence, the pins of the MCU toggle in this way also.

Most AVR instructions execute in exactly 1 clock cycle. Some take longer...
namely, anything that branches or otherwise causes PC (the Program Counter)
to change against its normal sequence. The exact no. of clock cycles per
instruction is predictable. Hence, we should be able to reliably predict the
rate at which pins will toggle, relative to the CPU clock.



## How do I build the firmware?

1.	Make sure you have the `avr-gcc` and `avrdude` packages installed. On Windows,
	you can install [WinAVR](http://winavr.sourceforge.net/download.html) to get both.
	There are various other options for installing and using these packages on
	Mac OS X and Linux, but you will have to seek them out for yourself, for now.

2.	Go into the directory where the source is, and run:

		make

3.	This will produce `test.bin` (a raw binary file of the Flash ROM image) and
	`test.hex` (an Intel HEX file that most ROM burners support).



## How do I load the firmware and test the hardware?

### Burning the firmware to the MCU's Flash ROM

1.	You will need some sort of Atmel AVR burner (i.e. ISP, or "In-System Programmer").
	I use (and have assumed) a
	[very cheap clone](http://www.ebay.com/sch/i.html?_sop=15&_from=R40&_sacat=0&_nkw=usbasp+-adapter&LH_PrefLoc=2&rt=nc&LH_BIN=1)
	of the popular USB-based
	[USBasp](http://www.fischl.de/usbasp/).

2.	Wire up the ISP to the ATtiny:

    | Header pin | Signal   | ATtiny13 pin |
    | ---------- | -------- | ------------ |
    | 1          | MOSI     | 5            |
    | 5          | /RESET   | 1            |
    | 7          | SCK      | 7            |
    | 9          | MISO     | 6            |
    | 2          | VCC (5V) | 8            |
    | 4,6,8,10   | GND      | 4            |

3.	Plug in the ISP and launch `avrdude` in terminal mode, from command-line,
	to verify you can communicate. The following command-line specifies that we're
	connecting to a USBasp (`-c usbasp`); the part we're interfacing with is
	an ATtiny13 (`-p t13`); and we're entering terminal mode (`-t`):

        $ avrdude -c usbasp -p t13 -t
        ...
        avrdude.exe: Device signature = 0x1e9007

        > dump flash
        0000  ff ff ff ff ff ff ff ff  ff ff ff ff ff ff ff ff  |................|
        0010  ff ff ff ff ff ff ff ff  ff ff ff ff ff ff ff ff  |................|
        0020  ff ff ff ff ff ff ff ff  ff ff ff ff ff ff ff ff  |................|
        0030  ff ff ff ff ff ff ff ff  ff ff ff ff ff ff ff ff  |................|

        > quit

4.	Assuming you've already built `test.hex`, use the following command to write
	to your chip:

		avrdude -c usbasp -p t13 -U flash:w:test.hex:i

	...which indicates we're performing a memory operation (`-U`); with the `flash`
	memory; for a write (`w`); using the file `test.hex`; which is in Intel HEX
	format (`i`).

	You may get warnings about `warning: cannot set sck period` but I don't think
	this will be a problem. It worked fine for my device.

### Verifying the firmware

I have assumed that after programming the ATtiny13, the USBasp will release its
ISP lines (i.e. MOSI, SCK, etc will go Hi-Z), so that they don't interfere with
the outputs and general operation of the ATtiny13.

If for some reason that's not
the case, it may be necessary to manually detach these lines or move the chip
to a separate test rig.

Given you now have the ATtiny13 programmed and powered, the only way you'll really
be able to verify that it's doing what it's supposed to is with a frequency counter
or oscilloscope.

As you probe each of pin 5, 6, 7, 2, and 3 in turn, you should see that they're
oscillating at respectively halving frequencies, each with a 50% duty cycle.


# Who wrote this?

This was written by [Anton Maurovic](http://anton.maurovic.com). You can use it
for whatever you like, but giving me credit with a link to http://anton.maurovic.com
would be appreciated!
