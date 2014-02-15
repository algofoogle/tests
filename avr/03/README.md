# `tests/avr/03`



## What is this?

This is my 3rd example on Atmel AVR assembly language. It builds on the
`avr/02` example, and demonstrates how to adjust the clock speed.

It is intended for an ATtiny13A, but should work
on any larger ATtiny, including ATtiny25, ATtiny45, and ATtiny85 --
default clocks may differ on some devices.



## What does it do?

This program works the same way as `avr/02` in that it uses a binary counter
to toggle PB0 to PB4 at halving frequencies through each bit. It also adjusts
the clock speed parameters to try and get as close as possible to 1.2MHz
(i.e. 9.6MHz / 8) on PB0.



## How does it work?

From power-on:

1.	The MCU automatically loads its own clock calibration value (0x69
	in my case) into OSCCAL. From testing, this gives an internal clock
	of about 8.8MHz on my ATtiny13A.

2.	My code loads R17 with an override value of 0x6E, which is the value that
	that I've determined gives my part the closest approximation of 9.6MHz.

3.	It "slides" the OSCCAL value -- by incrementing or decrementing in a loop
	as required -- from its default to the value in R17. It's done this way
	by recommendation of the datasheet, which says that OSCCAL should not
	change by too large a value in one go.

4.	It disables the Clock Pre-scaler, which allows the CPU to run at full speed.

The rest of what it does is then the same as per the `avr/02` example:

1.	PB5..0 are configured to be outputs, though PB5 is unused because it is
	configured (by fuse bits) as External `/RESET`.

2.	Register `R16` is loaded with `0`, and written out to `PORTB`.

3.	In a loop, `R16` is incremented and written out to `PORTB`, over and over.

4.	R16 will wrap after 256 iterations, so the counter will cycle endlessly.

5.	The net effect is that bits in R16 toggle at a constant rate (where PB1
	toggles at half the rate of PB0; PB2 at half the rate of PB1; and so-on).
	Hence, the pins of the MCU toggle in this way also.



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

Ensure a 100nF capacitor is wired -- as closely as possible to the MCU -- to
bridge the VCC and GND pins. This is a decoupling capacitor to reduce the
severe noise that would otherwise be caused by the pins of the MCU switching
rapidly.

Given you now have the ATtiny13 programmed and powered, the only way you'll really
be able to verify that it's doing what it's supposed to is with a frequency counter
or oscilloscope -- attaching LEDs will be no good as they'll be oscillating
at frequencies significantly higher than you can see.

As you probe each of pin 5, 6, 7, 2, and 3 in turn, you should see that they're
oscillating at respectively halving frequencies, each with a 50% duty cycle.
If you have a dual-trace (or quad-trace) oscilloscope, you sould be able to
see multiple lines oscillating in sync at factors of PB0's (pin 5) rate.



## Findings

This has worked as I expected. My oscilloscope shows high-frequency oscillations
on PB0, and I can verify by the frequency counter in my DMM that there is a
304.4kHz signal on **PB2** -- 300kHz was the target, so this error of 1.5% is tolerable.

I can see on the oscilloscope that the frequency bounces around a little... varying
by as much as +/- 1%, but typically it's about +/- 0.3%. As the day warmed up, the clock
sped up marginally.



## Who wrote this?

This was written by [Anton Maurovic](http://anton.maurovic.com). You can use it
for whatever you like, but giving me credit with a link to http://anton.maurovic.com
would be appreciated!
