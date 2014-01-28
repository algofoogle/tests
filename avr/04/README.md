# `tests/avr/04`



## What is this?


This is a simple program in AVR Assembly that generates a waveform with
a 14ms period, and a 10/14 (71.4%) duty cycle -- that is, it's high for
10ms and low for 4ms.

It is intended for an ATtiny13A, but should work
on any larger ATtiny, including ATtiny25, ATtiny45, and ATtiny85 --
default clocks may differ on some devices.



## What does it do?

The firmware uses a naive cycle-counting approach (with dummy loops for
delays) to try and generate a signal on PB0 that is low for 4ms and high
for 10ms, such that it produces a 71.4Hz frequency with a 71.4% (10/14)
duty cycle.



## How does it work?

From power-on:

1.  The MCU automatically loads its own clock calibration value (0x69
    in my case) into OSCCAL. From testing, this gives an internal clock
    of about 8.8MHz on my ATtiny13A.

2.  My code loads R17 with an override value of 0x6E, which is the value that
    that I've determined gives my part the closest approximation of 9.6MHz.

3.  It "slides" the OSCCAL value -- by incrementing or decrementing in a loop
    as required -- from its default to the value in R17. It's done this way
    by recommendation of the datasheet, which says that OSCCAL should not
    change by too large a value in one go.

4.  It disables the Clock Pre-scaler, which allows the CPU to run at full speed.

5.  All of PORTB is configured for output.

6.  PB0 is set high.

7.  A delay of 10ms is executed, using a macro which has two loops with
    precise cycle-counting.

8.  PB0 is toggled, causing it to go low.

9.  Another delay of 4ms is executed, using the same macro with a different
    parameter.

10. PB0 is toggled, causing it to go high again.

11. We loop back to step 7.



## How do I build the firmware?

1.  Make sure you have the `avr-gcc` and `avrdude` packages installed. On Windows,
    you can install [WinAVR](http://winavr.sourceforge.net/download.html) to get both.
    There are various other options for installing and using these packages on
    Mac OS X and Linux, but you will have to seek them out for yourself, for now.

2.  Go into the directory where the source is, and run:

        make

3.  This will produce `test.bin` (a raw binary file of the Flash ROM image) and
    `test.hex` (an Intel HEX file that most ROM burners support).



## How do I load the firmware and test the hardware?

### Burning the firmware to the MCU's Flash ROM

1.  You will need some sort of Atmel AVR burner (i.e. ISP, or "In-System Programmer").
    I use (and have assumed) a
    [very cheap clone](http://www.ebay.com/sch/i.html?_sop=15&_from=R40&_sacat=0&_nkw=usbasp+-adapter&LH_PrefLoc=2&rt=nc&LH_BIN=1)
    of the popular USB-based
    [USBasp](http://www.fischl.de/usbasp/).

2.  Wire up the ISP to the ATtiny:

    | Header pin | Signal   | ATtiny13 pin |
    | ---------- | -------- | ------------ |
    | 1          | MOSI     | 5            |
    | 5          | /RESET   | 1            |
    | 7          | SCK      | 7            |
    | 9          | MISO     | 6            |
    | 2          | VCC (5V) | 8            |
    | 4,6,8,10   | GND      | 4            |

3.  Plug in the ISP and launch `avrdude` in terminal mode, from command-line,
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

4.  Assuming you've already built `test.hex`, use the following command to write
    to your chip:

        avrdude -c usbasp -p t13 -U flash:w:test.hex:i

    ...which indicates we're performing a memory operation (`-U`); with the `flash`
    memory; for a write (`w`); using the file `test.hex`; which is in Intel HEX
    format (`i`).

    You may get warnings about `warning: cannot set sck period` but I don't think
    this will be a problem. It worked fine for my device.

5.  NOTE: I've sometimes found problems where the chip is already running, and
    `avrdude` will not be able to communicate properly with the chip straight
    away, giving output like this:

        avrdude: Device signature = 0x010102
        avrdude: Expected signature for ATtiny13 is 1E 90 07
                 Double check chip, or use -F to override this check.

    In these cases I've generally found that this works:

    1.  **Force** `avrdude` to go into its terminal:

            avrdude -c usbasp -p t13 -t -F

    2.  During this time, the device may be running when it's **not supposed to be**.
        You can verify this, to an extent, by running the `sig` command and seeing
        garbage device signatures instead of the expected `1E xx yy` pattern.

    3.  Issue the `pgm` command and hopefully the chip will properly be halted and
        you'll see the correct signature.

    4.  Issue the `erase` command.

    5.  `quit` out of AVRDUDE.

    Hopefully, after this, you should be able to issue the normal burn command again.


### Verifying the firmware

Ensure a 100nF capacitor is wired -- as closely as possible to the MCU -- to
bridge the VCC and GND pins. This is a decoupling capacitor to reduce the
severe noise that would otherwise be caused by the pins of the MCU switching
rapidly.

Using an oscilloscope on PB0, you should be able to verify the expected
waveform. A frequency counter should be able to verify a frequency of about
71.4Hz. Even a loudspeaker or earphone attached to PB0 -- with (say) a 100-ohm
resistor to ensure there is not too much current on that pin -- should produce a low
frequency tone (about D2 on the chromatic scale).


## Findings

This has worked as I expected. My oscilloscope verifies a waveform on PB0 that is
low for 4ms and high for 10ms.



## Who wrote this?

This was written by [Anton Maurovic](http://anton.maurovic.com). You can use it
for whatever you like, but giving me credit with a link to http://anton.maurovic.com
would be appreciated!
