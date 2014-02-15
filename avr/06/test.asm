; Title::     Anton AVR test 06
; Author::    Anton Maurovic <anton.maurovic@gmail.com>
; URL::       http://anton.maurovic.com/
;             http://github.com/algofoogle/tests
;
; Description::
;
;   This sets up a timer that fires an interrupt every 2ms. It also sets up `Z`
;   (which is a 16-bit pointer formed of the combination `r30:r31`) to point to
;   a jump table (with 7 entries in it, representing the repeating 14ms cycle).
;   The ISR uses the jump table for automatically directing execution flow
;   depending on which stage we're up to:
;   
;   1.  (2ms) Turn on PB1.
;   2.  (4ms) Do nothing special; PB1 is still on.
;   3.  (6ms) Turn off PB1. It was high for a total of 4ms.
;   4.  (8ms) Do some work: read 8 bytes from a data table in Program Memory and
;       rapidly toggle PB1 to reflect each bit of each byte, in sequence:
;       5us per bit, with a gap of 20us per byte.
;   5.  (10ms) Set PB0 low.
;   6.  (12ms) Do nothing special; PB0 is still low.
;   7.  (14ms) Set PB0 high, and reset `Z` to point to the start of the jump
;       table again, allowing the 14ms cycle to repeat on the next ISR hit.
;   
;   The result is:
;   
;   *   A 71.4Hz waveform on PB0 with a 71.4% (10/14) duty cycle.
;   *   There is serial data present on PB1 for a total of about 480us,
;       every 14ms.
;   *   In addition to that, there is a 4ms period (out of each 14ms cycle)
;       that PB1 is held high.
;
; Burning info::
;
; ***    LOW fuse byte:  0x6A
; ***    HIGH fuse byte: 0xFF
; ***    EEPROM:         Not used
;
; Usage info::
;
;   If you've correctly burned this to an ATtiny13, and powered up at 5V,
;   put an LED (in series with a 470-ohm resistor) between `PB0` and GND, and
;   the same at `PB1`:
;
;   *   The LED driven by `PB0` should be fairly bright, as the `PB0` duty cycle is
;       about 71% (meaning the LED is switched on for most of the time).
;   *   The LED driven by `PB1` will only be about half as bright, as the `PB1` duty
;       cycle is only about 32%... though the characteristics of human light perception
;       mean it might actually be a less-obvious difference.
;
;   Further verification can be done with an oscilloscope attached to these two pins.
;

.include "t13.asm"
.include "macros.asm"


; Interrupt table starts at 0x0000. ATtiny13A has 10 interrupt vectors (inc. RESET):
.org 0x0000
firmware_top:
; Reset vector comes first:
    rjmp main
; The other 9 interrupts all just return without doing anything, at the moment:
    reti                ; Interrupt Vector 2   = EXT_INT0   (External Interrupt Request 0)
    reti                ; Interrupt Vector 3   = PCINT0     (Pin Change)
    reti                ; Interrupt Vector 4   = TIM0_OVF   (Timer Overflow)
    reti                ; Interrupt Vector 5   = EE_RDY     (EEPROM Ready)
    reti                ; Interrupt Vector 6   = ANA_COMP   (Analog Comparator)
    rjmp timer_isr      ; Interrupt Vector 7   = TIM0_COMPA (Timer Compare Match A)
    reti                ; Interrupt Vector 8   = TIM0_COMPB (Timer Compare Match B)
    reti                ; Interrupt Vector 9   = WDT        (Watchdog Timeout)
    reti                ; Interrupt Vector 10  = ADC        (ADC Conversion Complete)


; Main program:
main:
    ; I've determined that an OSCCAL value of 0x6E gives the best approximation
    ; of 9.6MHz on my ATtiny13A.
    slide_osccal 0x6E

    ; Make the CPU clock run at full speed:
    disable_clock_prescaler

    init_stack

    ; Set all pins to be outputs:
    ser r16                 ; R16 <- 0xFF
    out DDRB, r16
    nop                     ; Synchronise.

    ; Set up PB0 to initially output a high value:
    sbi PORTB, PB0

    ; Set up PB1 to initially output a low value:
    cbi PORTB, PB1

    ; Set up the Z (16-bit) pointer to point to the _timer_isr_jumps table.
    ; As timer_isr fires each time, this Z pointer gets incremented to jump to the next
    ; point in the jump table, for directing execution according to each of
    ; 7 stages in the 14ms cycle:
    clr ZH
    ldi ZL, pm_lo8(_timer_isr_jumps)
    ; NOTE: We're assuming all of the jump table is below the 256th program
    ; memory address in this firmware. If it wasn't, we'd have to use ZH
    ; too, which means instructions to handle rolling over ZL into ZH
    ; as we update the Z pointer per each ISR hit.

    ; Configure timer to generate an interrupt every 2ms...
    ; That is, after 75/(CLK/256) seconds =>
    ;   75/(9,600,000/256) = 0.002 = 2ms
    ;
    init_simple_timer clk_256, 75

sleep_loop:
    ; Enable "Idle" sleep mode:
    enable_sleep
    ; Sleep -- basically, halt the CPU and let interrupts fire when required:
    sleep
    ; I think we get here when a RETI occurs from within an ISR.
    rjmp sleep_loop
    
; This is an ISR (Interrupt Service Routine) that handles TIM0_COMPA
; (i.e. interrupt generated when when Timer/Counter 0 hits a given limit
; in OCR0A). This is currently configured to fire every 2ms.
; 
; This ISR uses the Z pointer with a jump table to jump to the stage it
; currently needs to process. After that, it increments (or resets) the
; Z pointer as required. These are the events that happen at specific
; times in the cycle:
;
;   *   After 2ms (1 interrupt), while PB0 is high, we want to do some
;       proof-of-concept "work".
;   *   After 10ms (4 more interrupts), we want to pull PB0 low.
;   *   After 14ms (2 more interrupts), we want to pull PB0 high again
;       and reset the interrupt counter.
;
; For the time while we're NOT in this ISR, the main program is just in SLEEP
; mode, so the MCU is idling. We COULD potentially do other work during this
; time but I have nothing for it to do at the moment.
;
timer_isr:
    ; Jump to whichever point in the jump table is currently indicated by
    ; the Z pointer. The landing address represents a stage of the 7
    ; stages of the cycle.
    ijmp                        ; 2 cycles.

_timer_isr_jumps:
    ; This is a jump table. Depending on how many times the interrupt has
    ; fired already, the IJMP above will land on one of these 7 slots --
    ; -- the 7th will reset the Z pointer to the start of the jump table.
    ; Note that each RJMP here adds 2 cycles to the ISR lead-in time:
                                ; 2 cycles each...
    rjmp _timer_isr_act_toggle  ; 1st interrupt (2ms passed): PB1 -> high.
    rjmp _timer_isr_step        ; 2: Nothing to do;           PB1 still high.
    rjmp _timer_isr_act_toggle  ; 3rd interrupt (6ms passed): PB1 -> low.
    rjmp _timer_isr_do_work     ; 4th interrupt (8ms passed): Do some work.
    rjmp _timer_isr_10ms        ; 5th interrupt (10ms passed): pull PB0 low.
    rjmp _timer_isr_step        ; 6: Nothing to do.
    .if ((. - firmware_top)>>1 >= 0x0100)
        ; Our implementation doesn't use ZH for the jump table, so we can't
        ; have any part of the jump table beyond PC address 0x0100:
        .error "_timer_isr's jump table is not located wholly under 0x0100 address"
    .endif
_timer_isr_end_cycle:
    ; This is the landing address of the 7th interrupt of the cycle, having
    ; reached the 14ms mark...
    ; NOTE: The next 2 instructions sync I/O with all other execution
    ; paths by matching the same CPU cycle count as for one of the RJMPs above.
    nop                                 ; 1 cycle.
    ; Reset Z pointer to the start of the jump table:
    ldi ZL, pm_lo8(_timer_isr_jumps)    ; 1 cycle.
    ; 14ms has elapsed...
    ; Pull PB0 high again:
    sbi PORTB, PB0
    ; Exit the ISR:
    reti

_timer_isr_act_toggle:
    ; When PB1 is not being used as the DATA channel in _timer_isr_do_work,
    ; it is being driven high for a period of 4ms out of 14ms. This is so it
    ; can drive an indicator LED, which shows that we're alive and kicking.
    ; This "toggle" event is called twice per each 14ms cycle -- once at the
    ; 2ms mark to turn the LED on, and once again at 6ms to turn it off.
    sbi PINB, PB1
    rjmp _timer_isr_step

_timer_isr_do_work:
    ; 2ms has elapsed...

    ; This routine reads a sequence of 8 bytes from within the Flash ROM
    ; Program Memory of the MCU, and writes each bit of each
    ; byte out -- MSB first -- using a 200kHz SPI approach.
    ; That is, each bit is clocked at 5us intervals. There is a gap
    ; of 20us between the LSB of one byte, and the MSB of the next.
    ; If you add that all up:
    ;   (8 bits * 5us + 20us) * 8 bytes
    ;   => The cycle is complete in 480us.

    ; Push Z onto the stack, because we need to mess with it here...
    push ZL
    push ZH     ; NOTE: We could leave this out, and just
                ; assume that ZH will stay at 0, always, or
                ; at least verify that it *starts* at 0 before
                ; the loop, and then reset it to 0 after the
                ; loop is done (i.e. "clr ZH" instead of "pop ZH").
                ; This would shave at least 2 instructions,
                ; and save 1 byte of stack (SRAM).
                ; IN FACT, we know what the next step will be
                ; in the jump table, so we could load its address
                ; directly and even do away with the PUSH/POP
                ; instructions completely:
                ; * Delete 2xPUSH
                ; * Delete "LDI ZH"
                ; * Change final 2xPOP to 2xLDI.
                ; ...which will save 3 instructions.
    ; Now point Z to the data bytes (using BYTE addresses)
    ; that we have in Program Memory:
    ldi ZL, lo8(data)
    ldi ZH, hi8(data)
    ; We'll push out 8 bytes in total:
    ldi r23, 8
next_byte_loop:
    ; Load a byte from the data bytes we have in Program Memory,
    ; incrementing the Z pointer afterwards:
    lpm r21, Z+                     ; 3 cycles.
    ; Write out one bit at a time on PB1, starting with MSB...
    ; 8 bits to shift out...
    ldi r22, 8                      ; 1 cycle.
next_bit_loop:
    ; Rotate left, pushing MSB into Carry.
    rol r21                         ; 1 cycle.
    brcs out_hi_bit                 ; 1 cycle if bit 0, 2 if bit 1.
    ; Bit is 0, so clear it on PB1:
    nop                             ; 1 cycle (sync).
    cbi PORTB, PB1                  ; 1 cycle.
    rjmp bit_loop_check             ; 2 cycles.
out_hi_bit:
    ; Bit is 1, so set it on PB1:
    sbi PORTB, PB1                  ; 1 cycle.
    nop                             ; 1 cycle (sync).
    nop                             ; 1 cycle (sync).
bit_loop_check:
    ; By this point, 6 cycles have been spent
    ; (3 since commencing the SBI or CBI instruction).
    ; We want to hold the PB1 (last output bit) state for 5us
    ; (48 cycles, minus the overhead built in to each iteration of the loop):
    ;   RequiredDelay = 48 - LoopHead - LoopTail
    ;   = 48 - 6 - 3
    ;   = 39 cycles we need to pad out:
    precise_delay 12, 1             ; 3*(12+1)*1 = 39 cycles.
    ; Check if we have more bits to loop thru, for this current byte:
    dec r22                         ; 1 cycle.
    brne next_bit_loop              ; 2 cycles.
    ; When we reach THIS point, outside of the loop, 44 cycles have elapsed
    ; since the last SBI or CBI instruction. We need to pad it out to 48
    ; so that the final bit (of this byte) definitely lasts 5us.
    nop
    nop
    nop
    nop
    ; Now we need to pull PB1 low (if it isn't already) and keep it there
    ; for 20us (192 cycles) before the first bit of the next byte is
    ; output. From cycle counting, we can tell that from the moment
    ; PB1 drops low again (at this next instruction), there are 11 cycles
    ; of overhead before the first bit of the NEXT byte can be output,
    ; so if we want precise timing we need to pad with a delay of
    ; 192-11=181 cycles.
    cbi PORTB, PB1                  ; 1 cycle.
    precise_delay 59, 1             ; 3*(59+1)*1 = 180 cycles.
    nop                             ; 1 cycle.
    ; Check if we have more bytes to pump out...
    dec r23                         ; 1 cycle.
    brne next_byte_loop             ; 2 cycles (unless all done).
    ; All bytes are done. Bring back the original Z pointer
    ; (jump table index) value from the stack:
    pop ZH
    pop ZL
    ; Exit the ISR after incrementing the Z pointer:
    rjmp _timer_isr_step

_timer_isr_10ms:
    ; 10ms has elapsed...
    ; Make PB0 go low.
    cbi PORTB, PB0

_timer_isr_step:
    ; Increment the Z pointer (as a 16-bit operation):
    inc ZL
_timer_isr_exit:
    reti

data:
    .byte 0b11100111, 0b11011011, 0b10000001, 0b10011001
    .byte 0b10101010, 0b11001100, 0b10111111, 0b11101101
