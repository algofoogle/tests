# `tests/avr/01`



## What is this?

This is an example Atmel AVR assembly language program that demonstrates
8-bit AVR programming. It is intended for an ATtiny13A, but should work
on any larger ATtiny, including ATtiny25, ATtiny45, and ATtiny85.



## What does it do?

This simple program reads the state of PB3 (pin 2), and produces an inverted
output of that state on PB4 (pin 3). That is:

*	If pin 2 is shorted to GND, pin 3 will be high (VCC).
*	If pin 2 is left disconnected, or shorted to VCC, pin 3 with be low (GND).



## How does it work?

From power-on:

1.	Pin 2 is configured to be an input, while all others are configured to be outputs.

2.	Pin 2 is configured to have its internal pull-up resistor enabled, so that it
	automatically reads as "high" if left disconnected.

3.	Pin 2 is read in an endless loop...

4.	If pin 2 is sensed to be high (i.e. 1), pin 3 is set low (i.e. 0, GND).

5.	If pin 2 is sensed to be low (i.e. 0), pin 3 is set high (i.e. 1, VCC).



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

3.	For testing purposes, wire up an LED and resistor (for current limiting) in series,
	between pin 3 and GND, and have a loose test wire that you can use to short pin 2
	to GND, later:

		                            ATtiny13:
		                        +------------ - -
		(Connected to ISP)      |
		- - --------------------| Pin 1 (/RESET)
		                        |
		                        |
		Test probe <------------| Pin 2 (input)
		                        |
		  LED | /               |
		  +---|<----/\/\/\------| Pin 3 (output)
		  |   | \   470-ohm     |
		  |                     |
		  +---------------------| Pin 4 (GND)
		  |                     |
		----- GND               +------------ - -
		 ---

4.	Plug in the ISP and launch `avrdude` in terminal mode, from command-line,
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

5.	Assuming you've already built `test.hex`, use the following command to write
	to your chip:

		avrdude -c usbasp -p t13 -U flash:w:test.hex:i

	...which indicates we're performing a memory operation (`-U`); with the `flash`
	memory; for a write (`w`); using the file `test.hex`; which is in Intel HEX
	format (`i`).

	You may get warnings about `warning: cannot set sck period` but I don't think
	this will be a problem. It worked fine for my device.

6.	You should now find that the ISP is supplying power, and the AVR is already running...
	With the probe on pin 2 just floating, pin 3 should be low (i.e. the LED should not
	be lit). Touch the probe to GND, pin 3 should go high, lighting up the LED.



## Findings

This functions exactly as I expected: After burning, the device is immediately running.
When I short pin 2 to GND, the LED on pin 3 lights up. When I disconnect pin 2 or attach
it to VCC, the LED goes out.



## Who wrote this?

This was written by [Anton Maurovic](http://anton.maurovic.com). You can use it
for whatever you like, but giving me credit with a link to http://anton.maurovic.com
would be appreciated!
