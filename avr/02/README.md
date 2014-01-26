# `tests/avr/02`



## What is this?

This is my 2nd example on Atmel AVR assembly language, demonstrating
very basic timing by cycle-counting. The intent is to predict the timing
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
|-----|-----|-------------|
| PB0 | 5   | Ref         |
| PB1 | 6   | Ref/2       |
| PB2 | 7   | Ref/4       |
| PB3 | 2   | Ref/8       |
| PB4 | 3   | Ref/16      |

PB0 ("Ref") is the fastest. Its actual rate is dependent on the system clock,
and needs to be predicted based on the number of CPU cycles required by the loop
that changes the pin states.



## How does it work?

From power-on:

1.	PB5..0 are configured to be outputs, though PB5 is unused because it is
	configured (by fuse bits) as External `/RESET`.

2.	Register `R16` is loaded with `0`, and written out to `PORTB`.

3.	In a loop, `R16` is incremented and written out to `PORTB`, over and over.

4.	R16 will wrap after 256 iterations, so the counter will cycle endlessly.

4.	The net effect is that bits in R16 toggle at a constant rate (where PB1
	toggles at half the rate of PB0; PB2 at half the rate of PB1; and so-on).
	Hence, the pins of the MCU toggle in this way also.

Most AVR instructions execute in exactly 1 clock cycle. Some take longer...
namely, anything that branches or otherwise causes PC (the Program Counter)
to change against its normal sequence. The exact number of clock cycles per
instruction is predictable. Hence, we should be able to reliably predict the
rate at which pins will toggle, relative to the CPU clock.

After writing the code, I calculated the following loop would generate a
'Ref' transition every 4 cycles, which means a Ref *frequency* at 1/8 of
the system clock:

```assembly
loop:
	; Write counter state to pins:
	out PORTB, r16			; 1 cycle.
	; Increment r16, causing cascading toggles to occur:
	inc r16					; 1 cycle.
	; Repeat the loop:
	rjmp loop				; 2 cycles.
```

If we assume CKDIV8 is in effect (i.e. because our fuse bits say it should be),
and it is not disabled during execution of the firmware, then the default
internal RC clock (supposedly calibrated to 9.6MHz) should be running at 1.2MHz,
and hence 1/8 of this gives 150kHz at PB0.


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
the outputs and general running of the ATtiny13. Meanwhile, it should leave the
ATtiny13 powered, so it can run its firmware freely.

If for some reason that's not
the case, it may be necessary to manually detach these lines or move the chip
to a separate test rig.

Given you now have the ATtiny13 programmed and powered, the only way you'll really
be able to verify that it's doing what it's supposed to is with a frequency counter
or oscilloscope -- attaching LEDs will be no good as they'll be oscillating
at frequencies significantly higher than you can see.

As you probe each of pin 5, 6, 7, 2, and 3 in turn, you should see that they're
oscillating at respectively halving frequencies, each with a 50% duty cycle.
If you have a dual-trace (or quad-trace) oscilloscope, you sould be able to
see multiple lines oscillating in sync at factors of PB0's (pin 5) rate.



## Findings

I had predicted that this code would produce a 150kHz signal on PB0 at a 50%
duty cycle, but the results were out by a bit. To summarise:

*	CKDIV8 **is** in effect the whole time, which means the system clock
	is divided by 8.
*	While the calibrated system clock is meant to be 9.6Mhz, to yield a
	*predicted* frequency of 150kHz on PB0 (after clock pre-scaling divides
	by 8, instruction cycles divide by 4, and we divide by 2 since two transitions
	are required for a complete cycle), the actual measured frequency on PB0 is
	about 138.5kHz... an error of 7.7%.
*	Before I could get accurate measurements and normal, reliable behaviour
	out of the MCU, I had to put a 100nF decoupling capacitor close to it,
	bridging its VCC and GND pins.

Here's the detail of what I tested:

*	When I tested it with a basic frequency-counting DMM (Digital Multimeter),
	I was seeing a response of 137kHz. This is while my ISP is still attached
	to all pins.
*	When I detached the ISP "MOSI" wire from pin 5 (PB0), the frequency rose
	to 139.2kHz.
*	As I detached the other ISP wires, this continued to rise to 143.2kHz with
	only the `/RESET` wire still attached to pin 1.
*	After I detached everything else except for VCC, GND, and my test point
	(and even detached a power-indicator LED and test LED on PB4), the
	frequency had risen to about 145kHz.
*	This is a significant enough rise by about 6% from "fully loaded" to
	effectively unloaded, and at worst it is about 9% slower than the target
	of 150kHz. This will have to be considered when designing a circuit
	with timing that *may* be critical -- an external crystal may be
	required for reliable timing, or the calibration may need to be adjusted
	to compensate for the expected load.
*	It's possible that the reliability of the IC was affected by the fact that
	I had PB3 accidentally shorted directly to GND when this fired up, which means
	it would have been trying to drive maximum current at this pin. Certainly
	the chip seemed to not even start up while this pin was grounded.
*	I found strange behaviour after a while when I tested other pins, esp.
	the (previously-shorted) pin 2 -- the frequencies all seemed to drop:

		PB0 => 16.30kHz
		PB1 =>  8.17kHz
		PB2	=>	4.08kHz
		PB3 =>  2.03kHz
		PB4 =>  2.01kHz <== Error!?

	And after this, behaviour got stranger with the frequency on PB0 bouncing
	all around the place between 28kHz and 800Hz. Either the chip is faulty;
	or the supply is noisy; or my DMM isn't coping; or there is other noise.

	When I re-attached my power-indicator LED, it seemed to normalise, back
	at about 137kHz.
*	I attached my oscilloscope between two separate GND lines of the same power
	supply (in this case, the GND lines of two separate USB ports), and found
	what looked like significant noise (as much as +/- 0.4V?). This was quite
	a bit worse when my power-indicator LED was removed.
*	I suspect I'm seeing noise from the rapidly fluctuating currents of the
	pins toggling (as well as the internal logic of the MCU), causing ringing
	(i.e. reflections) down the otherwise long, unshielded cable supplying
	the MCU. To make matters worse, the other wires of that same cable
	are being driven directly by the pins on the MCU with rapid switching,
	which would be causing all kinds of capacitance issues.
*	This is why decoupling capacitors are required: I wired a 100nF capacitor
	directly across GND and VCC of the MCU, and straight away the signal
	between my two GND lines was dramatically cleaner, except for one big spike
	every 3.6uS, which is when PB0 (and hence all other pins) transition.
*	After adding this decoupling capacitor, everything seemed to normalise...
	the frequency of PB0, according to both my oscilloscope and DMM frequency
	counter is pretty much spot on 138.5kHz.
*	As is to be expected with an internal RC oscillator, the frequency changed
	with the temperature of the chip, and even with pressure:
	*	I heated the chip to -- I think -- about 40 or 50 degrees celsius,
		using my hot air reflow station. This caused the frequency to rise
		to about 150kHz, and it fell back down again gradually as it cooled.
	*	I applied a moderate amount of mechanical pressure to the package
		of the chip, using the butt of a pencil, and this caused the frequency
		to noticeably rise by about 0.3%.
*	According to my DMM, the supply voltage of the chip is 4.94V, while on another
	USB port it is about 5.04V. When running on this different supply, the clock
	is marginally faster: 139.8kHz instead of 138.5kHz => the 2% difference
	on the supply seems to make a 1% difference to the internal RC oscillator.
*	I tried with another chip (from the same MFG batch) and it gave pretty
	much the same frequency.


## Who wrote this?

This was written by [Anton Maurovic](http://anton.maurovic.com). You can use it
for whatever you like, but giving me credit with a link to http://anton.maurovic.com
would be appreciated!
