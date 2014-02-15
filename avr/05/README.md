# `tests/avr/05`



## What is this?

This is a simple program in AVR Assembly that uses a timer interrupt to
generate a waveform and do other work on a schedule. It also demonstrates
better macros, and the use of "include" files.

It is intended for an ATtiny13A, but should work
on any larger ATtiny, including ATtiny25, ATtiny45, and ATtiny85 --
default clocks may differ on some devices.



## Table of Contents

*   [What does this do?](#what-does-it-do)
*   [How does it work?](#how-does-it-work)
*   [How do I load the firmware and test the hardware?](#how-do-i-load-the-firmware-and-test-the-hardware)
    ... and [Verifying the firmware](#verifying-the-firmware)
*   [Findings](#findings)
*   [Who wrote this?](#who-wrote-this)



## What does it do?

The firmware sets up a timer that fires an interrupt every 2ms.
The ISR (Interrupt Service Routine) counts the number of times it
has fired, up to 14. At various counts it has the opportunity to
perform any required action. The events that currently take place
are at:

*   2ms (ISR hit no. 1): Toggle the PB1 pin at 10kHz, for 1.5ms.
*   10ms (ISR hit no. 5): Pull PB0 low.
*   14ms (ISR hit no. 7): Pull PB0 high, and reset ISR hit count to 0.

The result is:

*   A 71.4Hz waveform on PB0 with a 71.4% (10/14) duty cycle.
*   PB1 is normally low, but has a 10kHz square wave burst
    that starts 2ms after PB0 goes high, and lasts 1.5ms.



## How does it work?


NOTE: Besides the procedure described below, there are other ways to
generate a waveform, including using the ATtiny13A's PWM-mode WGM
(Waveform Generator Mode). The approach used in this code, however, is
a moderately simple solution that allows for more
complex event-based processing where required.


### Part 1: Initialisation after power-on:

1.  The MCU automatically loads its own clock calibration value (0x69
    in my case) into `OSCCAL`. From testing, this gives an internal clock
    of about 8.8MHz on my ATtiny13A.

2.  The `slide_osccal` macro is used to gradually adjust `OSCCAL` until it
    reaches the target value of `0x6E`, which is the value that
    that I've determined gives my ATtiny13 the closest approximation of 9.6MHz.

3.  The `disable_clock_prescaler` macro does just that, allowing the CPU to
    run at the full 9.6MHz speed of its internal clock.

4.  The `init_stack` macro sets the stack pointer (`SPL`) to the top of
    the MCU's SRAM; the stack (used in this case for storing the ISR's
    return address) grows downward from the top of SRAM.

5.  All of `PORTB` is configured for output.

6.  `PB0` is set high, and `PB1` is set low.


### Part 2: Setting up the timer and its interrupt:

1.  `CLI` globally disables interrupts, so they can be configured safely.

2.  The Timer/Counter is locked into reset mode (`PSR10` bit) so we can
    configure it without it starting prematurely.

3.  Bit fields in `TCCR0A` and `TCCR0B` are used to configure multiple
    aspects of the Timer/Counter:

    | Field bits   | Register bits | Value | Effect |
    | -----------  | ------------- | -----:| ------ |
    | `COM0A[1:0]` | `TCCR0A[7:6]` | `00b` | "Output Compare A" has no effect on `PB0` pin |
    | `COM0B[1:0]` | `TCCR0A[5:4]` | `00b` | "Output Compare B" has no effect on `PB1` pin |
    | `WGM[2:0]`   | `TCCR0B[3]` + `TCCR0A[1:0]` | `010b` | CTC: Clear `TCNT0` when it hits `OCR0A` & flag `TIM0_COMPA` interrupt |
    | `CS0[2:0]`   | `TCCR0B[2:0]` | `100b` | Timer clocked at `CLK/256` |

4.  `OCR0A` is set to `75`, so that when `TCNT0` hits 75, CTC mode will reset the counter
    and flag the `TIM0_COMPA` interrupt. At `75 / (9.6MHz/256)`, the interrupt will be
    flagged every 2ms.

5.  `TIMSK0` gets (only) bit 2 set (i.e. `00000100b`), so that the `TIM0_COMPA` interrupt
    will be able to fire.

6.  `TCNT0` is reset, so the counter will definitely start at 0.

7.  Timer/Counter is brought out of reset (after it was locked in step 2),
    causing the timer to start.

8.  `R20` is cleared -- it will be used to count how many times the
    interrupt has fired.

9.  `SEI` globally enables interrupts -- only `TIM0_COMPA` is actually active, though.


### Part 3: Going to `SLEEP` and waiting for an interrupt:

1.  The value of `MCUCR` is read into `R16`.

2.  In `R16`, the `SE` (Sleep Enable) bit is turned on, while
    the `SM[1:0]` bits are cleared, to select "Idle" mode. This will
    stop the CPU clock during a SLEEP, but let all other internals
    continue to run.

3.  This is written back to `MCUCR`.

4.  The `SLEEP` instruction is issued. The CPU should now be halted.

5.  Execution **will** continue after the `SLEEP` instruction, but only
    when any interrupt has fired and returned.

6.  At this point, an endless loop repeats all of this "Part 3", from 
    step 1.


### Part 4: The timer ISR:

The timer ISR (`TIM0_COMPA`) fires every time `TCNT0` reaches 75,
i.e. every 2ms. Assuming this is the initial state, and hence `R20`
(the interrupt count) is at 0...

1.  The CPU is initially stalled at the `SLEEP` instruction.

2.  When the `TIM0_COMPA` interrupt then fires (for the first time),
    interrupts are automatically disabled by the MCU, and
    the return address (i.e. the address of next instruction after
    `SLEEP`) is pushed on the stack. The CPU jumps to the `TIM0_COMPA`
    interrupt vector and "wakes up", resuming execution.

3.  It executes `rjmp timer_isr`, entering the ISR.

4.  `R20` is incremented to 1, indicating that this is the first hit
    on the ISR, and hence that 2ms has elapsed since the timer was
    started.

5.  Next comes a sequence of checks to see what `R20` is up to...

    1.  If `R20` is 1, then 2ms has elapsed;
        the ISR jumps to a loop that toggles PB1 30
        times, with a delay of 50us between each iteration. This produces
        a 10kHz square wave for 1.5ms.

    2.  If `R20` is 5, then 10ms (in total) has elapsed;
        the ISR jumps to code which does nothing but pull `PB0` low.

    3.  If `R20` is 7, then 14ms (in total) has elapsed;
        the ISR continues on to pull `PB0` back high again, and resets
        the interrupt counter back to 0.

    4.  *Otherwise*, if none of these conditions are met, the ISR has
        nothing to do for this particular interrupt hit.

    Note that all execution paths have been cycle-counted (and `NOP`
    instructions inserted to pad the difference) to ensure that
    pin outputs are synchronised to occur exactly the expected amount of time
    after each other.

6.  Each of these execution paths above ends by exiting the ISR (with `RETI`),
    which pops the return address off the stack, jumps to it, and
    re-enables interrupts.

7.  At this point, the CPU lands at the instruction after `SLEEP`, and
    continues running. This causes it to jump back (in an endless loop)
    to the code in [Part 3](#part-3-going-to-sleep-and-waiting-for-an-interrupt),
    where it promptly goes to sleep again until the next timer interrupt fires.



## How do I load the firmware and test the hardware?

### Burning the firmware to the MCU's Flash ROM

Prior tests in this repo have info on
[burning the firmware to the MCU using a USBasp](https://github.com/algofoogle/tests/tree/master/avr/04#how-do-i-load-the-firmware-and-test-the-hardware).
I've also made it so you can clean, compile, **and** burn to the chip all in one go:

    make rewrite

If you have problems with any of the burn methods, though, see below...

### If you have problems burning the firmware...

I've started to regularly have problems re-writing the firmware of my ATtiny13A,
when using AVRDUDE under Windows XP. I have managed to work around these all, so
far. I'm not yet sure [what the cause is](#what-causes-these-problems).

Anyway, the type of error I see when trying to start any AVRDUDE communication
with the chip (for example, when trying to connect in AVRDUDE `-t` terminal mode):

    $ avrdude -c usbasp -p t13 -t

    (...etc...)
    avrdude: Device signature = 0x010102
    avrdude: Expected signature for ATtiny13 is 1E 90 07
             Double check chip, or use -F to override this check.

The following procedure *generally* allows me to work around the problem:

1.  Try going into the AVRDUDE terminal in "force mode":

        make burntermf
        # Equivalent to: avrdude -c usbasp -p t13 -t -F

2.  Hopefully you will just get a terminal with no signature warning, that looks
    something like this:

        (...etc...)
        Reading | ################################################## | 100% 0.02s

        avrdude: Device signature = 0x1e9007
        avrdude> 

    If so, issue the `erase` command then `quit`:

        avrdude> erase
        >>> erase
        avrdude: erasing chip
        avrdude: warning: cannot set sck period. please check for usbasp firmware update.
        avrdude> quit
        >>> quit

        avrdude done.  Thank you.

    If this works OK, go to step 5.

3.  If the terminal comes up with a warning about the *expected signature*:

        avrdude: Device signature = 0x000106
        avrdude: Expected signature for ATtiny13 is 1E 90 07
        avrdude: current erase-rewrite cycle count is 2021359231 (if being tracked)

    ...then you should
    issue the `pgm` command which will *hopefully* reset the chip properly and allow
    you to run the `sig` command to verify it has the correct signature.

    Assuming this is working OK, go to step 5.

4.  If the terminal just bombs out when you issue the `pgm` command, you will
    probably find that the USBasp is still active (i.e. two LEDs are lit).
    The error when it bombs out (if you used `make burntermf`) will probably
    look like this:

        avrdude> pgm
        >>> pgm
        make: *** [burnterm] Error -1073741819
        $

    This is not normal and, as far as I know, is an AVRDUDE (or driver) bug manifesting
    as a Windows `0xC0000005` "Access Violation" error. Don't worry! I've found I can
    get around this too:

    1.  Assuming you've already tried issuing `pgm` and it bombed out...
    2.  Go back into the ARVDUDE terminal with: `make burntermf`
    3.  Hopefully you'll see it correctly identifies itself now.
    4.  Issue the `erase` and `quit` commands.

5.  You should now be able to clean, compile, and burn with:

        make rewrite


#### What causes these problems?

Frequently the problem *seems* to be an SPI alignment error -- i.e. where the MCU
thinks it has received more (or fewer) SPI bits than it expects, and so commands
and responses appear broken. I don't know whether this is due to:

*   A fault, or out-of-spec behaviour from my very cheap USBasp or its firmware;
*   My host Windows machine;
*   AVRDUDE itself;
*   Capacitance issues;
*   Noise caused by other devices attached to the circuit (e.g. my test equipment).

I've anecdotally seen the device start responding normally to AVRDUDE after I've
detached test equipment **and** a power LED I have hanging off the USBasp, but
not necessarily always...?


### Verifying the firmware

Ensure a 100nF capacitor is wired -- as closely as possible to the MCU -- to
bridge the VCC and GND pins. This is a decoupling capacitor to reduce the
severe noise that would otherwise be caused by the pins of the MCU switching
rapidly.

Using a CRO (oscilloscope) on PB0 and PB1, with a Time/Div of 2mS, each division
stepping horizontally from left to right should represent one hit of the ISR. With
the CRO set to trigger on the falling edge of PB0, you should see a waveform
resembling the following:

    PB0:     ___________________         _______ ...
            |                   |       |
     _______|                   |_______|

    PB1:        
                XXX                         XXX
     ___________XXX_________________________XXX_ ...

    |       |   |               |       |   |
    5  6  7(0)  1   2   3   4   5   6 7(0)  1   2...

Numbers that I've added along the bottom represent the value of `R20`, i.e. the
interrupt hit number. The key events are marked at 0, 1, and 5:

*   0 (which is also 7) is the end of a 14ms cycle, when the interrupt counter is
    reset and `PB0` goes high.
*   1 is when 2ms have elapsed at the start of the next cycle. This is when `PB1`
    oscillates rapidly at 10kHz (represented by `X`).
*   (Nothing happens at events 2, 3, and 4).
*   5 is when 10ms have elapsed in the cycle, at which point `PB0` goes low.
*   The cycle then comes back to 7 (0) and repeats.

Other ways to test include:

*   Putting a 470-ohm resistor on `PB0`, and one also on `PB1`. An LED with its cathode
    at GND and its anode on the other end of the `PB0` resistor should be fairly bright,
    as the `PB0` duty cycle is high (meaning the LED is switched on for most of the
    time). Meanwhile if that LED is tested against `PB1` instead, it should be quite
    dim, as the total relative duty cycle of `PB1` is *much* lower.

*   With those resistors in place, a speaker attached to `PB0` should produce a fairly
    simple low frequency square wave tone. Attached to `PB1` the same fundamental
    frequency is still audible, but much more "tinny", with a distinct high-pitched
    overtone. This is the 10kHz oscillation coming thru, while the relative duty cycle
    of `PB1` attenuates the lower (~71Hz) frequency considerably.

*   A frequency counter attached to `PB0` should read ~71Hz. Attached to `PB1` it might
    be hard to predict what reading you will get, but it's likely to be around
    `15/0.014 = 1.07kHz` (as there are 15 cycles every 14ms).


## Findings

This has worked exactly as I expected, and predicted above. The waveform on my CRO
is as given above, though stretched very slightly. This is because the internal RC clock
of the MCU is running about 1.3% slower than the target 9.6MHz. This is backed up by
the fact that my DMM's frequency counter measures the frequency on `PB0` to be 70.5Hz
instead of the expected 71.4Hz -- an error of -1.26%


## Who wrote this?

This was written by [Anton Maurovic](http://anton.maurovic.com). You can use it
for whatever you like, but giving me credit with a link to http://anton.maurovic.com
would be appreciated!
