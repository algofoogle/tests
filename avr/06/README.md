# `tests/avr/06`



## What is this?

This program in AVR Assembly builds on the
[`avr/05`](https://github.com/algofoogle/tests/tree/master/avr/05) example.
It uses a timer interrupt to perform various activities, at different times,
within a repeating 14ms cycle. It also demonstrates a jump table via the
`Z` pointer, and reading data from the the Flash Program Memory using the
`LPM` instruction. This is *leading* to a goal of sending data out via SPI.

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

This sets up a timer that fires an interrupt every 2ms. It also sets up `Z`
(which is a 16-bit pointer formed of the combination `r30:r31`) to point to
a jump table (with 7 entries in it, representing the repeating 14ms cycle).
The ISR uses the jump table for automatically directing execution flow
depending on which stage we're up to:

1.  (2ms) Turn on PB1.
2.  (4ms) Do nothing special; PB1 is still on.
3.  (6ms) Turn off PB1. It was high for a total of 4ms.
4.  (8ms) Do some work: read 8 bytes from a data table in Program Memory and
    rapidly toggle PB1 to reflect each bit of each byte, in sequence:
    5us per bit, with a gap of 20us per byte.
5.  (10ms) Set PB0 low.
6.  (12ms) Do nothing special; PB0 is still low.
7.  (14ms) Set PB0 high, and reset `Z` to point to the start of the jump
    table again, allowing the 14ms cycle to repeat on the next ISR hit.

The result is:

*   A 71.4Hz waveform on PB0 with a 71.4% (10/14) duty cycle.
*   There is serial data present on PB1 for a total of about 480us,
    every 14ms.
*   In addition to that, there is a 4ms period (out of each 14ms cycle)
    that PB1 is held high.

Compared with previous examples in this repo, this one puts all general
initialisation stuff into macros. The bulk of the code seen in the main
`test.asm` source file is just the interesting stuff that's unique to what
this program does.



## How does it work?


### Part 1: Initialisation after power-on:

1.  `slide_osccal` gradually adjusts `OSCCAL` until it reaches my target value
    of `0x6E`, which gives the best approximation of 9.6MHz on *my* ATtiny13.

2.  `disable_clock_prescaler` does just that, allowing the CPU to
    run at the full 9.6MHz speed of its internal clock.

3.  `init_stack` sets the stack pointer to the top of the MCU's SRAM.
    This is required for the ISR call/return, as well as `PUSH` and `POP`
    instructions used in the ISR.

4.  All of `PORTB` is configured for output.

5.  `PB0` is set high, and `PB1` is set low.

6.  `init_simple_timer` configures the timer:
    
    *   Direct timer output (via `PB0` and `PB1`) is **disabled**.
    *   It's clocked at CLK/256 (i.e. 37.5kHz); `CS0` mode 4.
    *   After every 75 counts, it will reset itself and fire the
        `TIM0_COMPA` interrupt; `WGM` mode 2 (`CTC`).
    
7.  `Z` (the 16-bit combination `r30:r31`) is pointed at the top of a
    jump table that will later be used by the ISR. `ZH` (i.e. `r30`)
    is set to `0`, and `ZL` (i.e. `r31`) is set to the low-byte of
    the **Program Memory address** of the `_timer_isr_jumps`
    jump table.

    NOTE: `ZH` doesn't have to be `0`, but I've done it this way because
    by keeping the whole jump table *beneath* the `0x0100` Program
    Memory address boundary, I can simplify incrementing and resetting
    `Z` by manipulting only `ZL`.

    NOTE: In the "avr25" architecture (used by the ATtiny13 and several
    others), each *instruction* is WORD-sized (i.e. two bytes) which means
    that when referring to a **Program Memory address**, you are indexing
    a WORD, and **not** a byte offset in the Program Memory. For example,
    "Program Memory address `0x0040`" points to *WORD-sized instruction*
    no. 64 in the Program Memory, which is located at the **byte** address
    `0x0080`. Incrementing `ZL` would hence point `Z` to `0x0041`; aka
    instruction no. 65; aka byte address `0x0082` in the Program Memory.

8.  <a name="part1-step8" />
    The MCU then enters an endless loop which just enables sleep mode
    (with the `enable_sleep` macro), puts the MCU to `SLEEP`, and then
    repeats if it gets woken up. This means it doesn't have to really
    do any work while waiting for the timer interrupt to fire. While
    this would do fine:
    
    ```nasm
    halt_loop:
        rjmp halt_loop
    ```
    
    ...doing it instead with the `SLEEP` instruction means the MCU will
    use less power. It's not hard to do, and has the same effect, so using
    the `SLEEP` instruction is worth it.

### Part 2: The timer ISR:

The timer ISR (`TIM0_COMPA`) fires every time `TCNT0` reaches 75,
i.e. every 2ms. Considering from the initial state, where hence `Z` points
to the start of the `_timer_isr_jumps` table...

1.  The ISR's first instruction is `IJMP`, which makes the MCU look up the
    Program Memory address stored in `Z`, and jumps to it. In this case,
    `Z` points to the **first** instruction in the jump table: a jump
    to `_timer_isr_act_toggle`.

2.  `_timer_isr_act_toggle` toggles the state of `PB1`; initially it is
    low, so this makes it go high.

3.  Execution jumps to `_timer_isr_step`, which increments `ZL` such that
    `Z` now points to the **second** instruction in the jump table.

4.  The ISR then exits with `RETI`. This will cause the MCU to end the
    `SLEEP` instruction from [step 8, above](#part1-step8), but it then
    promptly loops and goes back into `SLEEP`. The MCU now waits until the
    next time the ISR fires...

5.  When the ISR next fires, it will repeat step 1, but this time `Z` points
    to the **second** instruction in the jump table, so it will follow a
    different execution path. Instructions 2—6 do the following:
    
    *   **2** (at 4ms in the cycle): `_timer_isr_step` -- This effectively
        does nothing; `Z` increments, and the ISR returns, ready to process
        the next interrupt. All instructions 1—6 do at least this much.
    *   **3** (at 6ms): `_timer_isr_act_toggle` again, as per step 2 --
        Toggle `PB1` again, this time making it go low.
    *   **4** (at 8ms): `_timer_isr_do_work` -- Streams data bits out
        on `PB1`. See [Part 3, below](#part-3-bit-streaming-section).
    *   **5** (at 10ms): `_timer_isr_10ms` -- Make `PB0` go low.
    *   **6** (at 12ms): `_timer_isr_step` again -- Do nothing.
    
    As mentioned in the first bullet point, all of these execution paths
    end with `_timer_isr_step`, which increments `Z` such that the next time
    the ISR fires, it will process the next execution path in the overall
    14ms cycle.
    
6.  When the ISR fires for the 7th time, its initial `IJMP` instruction this
    time lands after the end of the jump table. The code there resets
    `Z` to point to the start of the jump table again, brings `PB0` back up
    high, and exits with `RETI`. Hence, the next time the ISR fires, it will
    repeat the overall 14ms cycle, starting at the top of the jump table
    again.

NOTE: The idea behind putting `PB1` high for 4ms (at step 1) is that we could
have an LED driven by it which indicates that the line is "active" and
"transferring data". Without this 4ms spent high out of every 14ms, the
*very brief* activity on `PB1` would not sufficiently illuminate an LED.

NOTE: All of these instructions are cycle-counted so we know that the
first time we manipulate either `PB0` or `PB1`, it is synchronised
(where appropriate) no matter which execution path was taken.

NOTE: The rate at which timers fire *could* be adjusted each time
from within a given path of the ISR. For example, `OCR0A` could be doubled
at key points (and reset in subsequent steps) to hence eliminate the
"do-nothing" steps.

### Part 3: Bit streaming section

The 4th time the interrupt fires (i.e. 8ms into the cycle), the main body
of this code does its work to output a stream of data bits. This is a
proof-of-concept that will be turned into more of an SPI stream, in a future
example.

1.  `Z` is saved, by pushing `ZL` and `ZH` onto the stack. We need to save
    it because it maintains our position in the ISR's jump table. The code
    below will temporarily use it for something else, and we'll restore it
    afterwards.

2.  Point `Z` to the *data* address of a data table (`data` label) that is
    stored in the Program Memory Flash ROM.

3.  Set `R23` to `8` as a counter for the number of bytes we need to read
    from the Program Memory (and stream via `PB1`).

4.  Use `LPM R21, Z+`, which load a byte from Program Memory (indexed by
    the `Z` pointer) into `R21`, and then increments `Z` (such that it
    will be pointing to the *next* byte when this instruction is next used).

5.  Set `R22` to `8` as a counter for the number of **bits** we need to
    stream out of `PB1`.

6.  Rotate the `R21` value left, which pushes its MSB into the Carry flag.

7.  If the Carry flag was set, then the bit we need to write to `PB1` is
    a logic 1. Otherwise, it's a logic 0. Either way, `PB1` is set high
    or low accordingly.

8.  A delay is inserted that -- with consideration for the overhead of all
    other instructions that make the loop and bit check work -- ensures the
    state of `PB1` is held for exactly 5us.

9.  `R22` is decremented and, if it's not yet `0`, we loop back to step 6
    again to push out the next bit.

10. Once all 8 bits of this byte have been written out, `PB1` is then made
    to go low, and a delay of 20us is inserted.

11. `R23` is decremented in the same way as per step 9, and assuming there
    are more **bytes** left to load and output, the code loops back to
    step 4.

12. If all 8 bytes have been written out, then `Z` (i.e. its jump table
    pointer value) is restored from the stack.

13. Finally, we let `Z` step to the next point in the jump table, ready for
    the next ISR (interrupt no. 5).



## How do I load the firmware and test the hardware?

### Burning the firmware to the MCU's Flash ROM

See [the burning instructions](https://github.com/algofoogle/tests/tree/master/avr/05#how-do-i-load-the-firmware-and-test-the-hardware)
in earlier examples, **including help
[if you have problems](https://github.com/algofoogle/tests/tree/master/avr/05#if-you-have-problems-burning-the-firmware).**

### Verifying the firmware

Ensure a 100nF capacitor is wired -- as closely as possible to the MCU -- to
bridge the VCC and GND pins. This is a decoupling capacitor to reduce
noise that would otherwise be caused by the pins of the MCU switching
rapidly.

Using a CRO (oscilloscope) on PB0 and PB1, with a Time/Div of 2mS, each division
stepping horizontally from left to right should represent one hit of the ISR. With
the CRO set to trigger on the falling edge of PB0, you should see a waveform
resembling the following:

    PB0:     ___________________         _______ ...
            |                   |       |
     _______|                   |_______|

    PB1:         _______                     ___ ...
                |       |   X               |
     ___________|       |___X_______________|

    |       |   |       |   |   |       |   |
    5   6 7(0)  1   2   3   4   5   6 7(0)  1   2...

Numbers that I've added along the bottom represent the interrupt hit number.
The key events are marked at 0, 1, 3, 4, and 5.

*   0 (which is also 7) is the end of a 14ms cycle, when `Z` is reset (to
    point back to the start of the jump table) and `PB0` goes high.
*   1 (2ms in) is when `PB1` goes high for what will be a 4ms period.
*   3 (6ms in) is when `PB1` goes low.
*   4 (8ms) is when there is a burst of binary data for 480us on `PB1`
    (as described in [Part 3, above](#part-3-bit-streaming-section)),
    represented here as `X`.
*   5 (10ms) is when `PB0` goes low.
*   The cycle then comes back to 7 (14ms, or 0) and repeats.

If you are able to zoom in on the "interrupt 4" event (i.e. the `X` in the
waveform diagram given above), you should see that it looks like this:

          ___  ___    __ __ __    _      _    _  __  _    _ _ _ _     __  __      _ ______    ___ __ _
       ...   __   ____  _  _  ____ ______ ____ __  __ ____ _ _ _ _____  __  ______ _      ____   _  _ ...

     Byte 0.......    1.......    2.......    3.......    4.......    5.......    6.......    7.......
      Bit 76543210    76543210    76543210    76543210    76543210    76543210    76543210    76543210
    Value 11100111    11011011    10000001    10011001    10101010    11001100    10111111    11101101

This shows that each bit is being output with correct timing, in the correct
order, per each of the 8 bytes in our `data` table of the Program Memory:

```nasm
data:
    .byte 0b11100111, 0b11011011, 0b10000001, 0b10011001
    .byte 0b10101010, 0b11001100, 0b10111111, 0b11101101
```

Other ways to test include:

*   Putting an LED (in series with a 470-ohm resistor) between `PB0` and GND, and
    the same at `PB1`:

    *   The LED driven by `PB0` should be fairly bright, as the `PB0` duty cycle is
        about 71% (meaning the LED is switched on for most of the time).
    *   The LED driven by `PB1` will only be about half as bright, as the `PB1` duty
        cycle is only about 32%... though the characteristics of human light perception
        mean it might actually be a less-obvious difference.

*   Testing with a small loudspeaker or earphone (again, in series with a 470-ohm resistor):

    *   Connected between `PB0` and GND, you should hear the speaker emit a low frequency
        tone (~71Hz).
    *   Connected between `PB1` and GND, it should emit the same fundamental frequency,
        but other frequencies should be a little more noticeable, producting a somewhat
        more noisy sound.

*   A frequency counter attached to `PB0` should read ~71.4Hz. Attached to `PB1` it might
    be hard to predict what reading you will get, but since `PB1` *rises* (i.e. transitions
    from low to high) for a total of 22 times *per 14ms*, you'd expect a measurement of
    about `22/0.014 = 1.57kHz`... though it's very much asymmetrical, and is actually
    a combination of multiple waveform events at different frequencies.


## Findings

I got the results I expected:

*   Frequency counter results on `PB0` and `PB1` are close enough to what I expected:
    70.8Hz and 1.557kHz respectively. This represents a consistent (systematic) clock
    error, where the internal RC oscillator is running about 1% slower than the target 9.6MHz.

*   Waveforms appear as predicted. I found a clibration error with my probe on `PB1`,
    but I corrected that:

    *   Contrary to what I expected, my oscilloscope probe on `PB1` showed capacitative
        rounding effects on rise and fall of the signal, most obviously on the 4ms peak.
    *   I had the probe set to "x10" (which is meant to reduce this effect).
    *   When I switched the probe to "x1" (and adjusted the channel voltage range,
        accordingly), this problem went away.
    *   I read up more on x1/x10 calibration [here](http://www.elexp.com/t_probe.htm)
        and [here](http://www.picotech.com/applications/how-to-tune-x10-oscilloscope-probes.html),
        and after adjusting the trimmer (on the BNC connector end of my probe),
        I had a clear, square-edged signal.

*   LEDs connected to each of `PB0` and `PB1` didn't have an *obvious* difference in
    brightness. While `PB0` *was* brighter, the difference wasn't dramatic. In fact, staring
    directly into the LEDs (I used common frosted 5mm red LEDs) the brightness was almost
    impossible to tell apart, and it wasn't until I looked at them from the side that the
    difference was more-apparent. This could be due to differences in the brightness
    response of the LEDs themselves, but is more likely due to the characteristics of
    human perception.

After reviewing my code, to write this README, I noticed that there are a few ways I can
shave some instructions from this firmware (if necessary). One way is if the SPI timing
doesn't have to be perfect (i.e. so long as its within tolerances) -- In that case, I can
delete several `NOP` instructions. Other improvements could be made by making a few
assumptions about the state and value of certain things, but more on that later...



## Who wrote this?

This was written by [Anton Maurovic](http://anton.maurovic.com). You can use it
for whatever you like, but giving me credit with a link to http://anton.maurovic.com
would be appreciated!
