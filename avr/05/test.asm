; Title::     Anton AVR test 05
; Author::    Anton Maurovic <anton.maurovic@gmail.com>
; URL::       http://anton.maurovic.com/
;             http://github.com/algofoogle/tests
;
; Description::
;
;   ...TBC...
;
; Burning info::
;
; ***    LOW fuse byte:  0x6A
; ***    HIGH fuse byte: 0xFF
; ***    EEPROM:         Not used
;
; Usage info::
;
;   ...TBC...

.include "t13.asm"
.include "macros.asm"


; Interrupt table starts at 0x0000. ATtiny13A has 10 interrupt vectors (inc. RESET):
.org 0x0000
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


timer_isr:
    inc r20             ; 1 cycle -- increment interrupt counter.
    cpi r20, 5          ; 1 cycle.
    breq hit_10ms       ; 1 cycle (if R20!=5) or 2 cycles (if R20==5).
    cpi r20, 7          ; 1 cycle.
    brne isr_exit       ; 1 cycle (if R20==7) or irrelevant otherwise.
    ; 14ms total has elapsed...
    ; +5 extra cycles to get here.
    ; Bring PB0 back up high, while we start another cycle.
    sbi PORTB, PB0
    ; Reset interrupt counter:
    clr r20
    ; ...
    ; TODO: Fill in extra work here, but it must fit within 2ms!
    ; ...
    ; Wait for 240us before doing anything:
    clr r17
pre_delay_loop:
    nop                 ; 1
    nop                 ; 1
    nop                 ; 1
    nop                 ; 1
    nop                 ; 1
    nop                 ; 1
    dec r17             ; 1
    brne pre_delay_loop ; 2
    ; Bounce PB1; we toggle it an even number of times:
    ldi r17, 74
bounce_loop:
    sbi PINB, PB1       ; 1
    ; 3*R18 cycles: {
    ldi r18, 62         ; 1
bounce_loop2:
    dec r18             ; 1
    brne bounce_loop2   ; 2
    ; } 186 cycles
    nop                 ; 1
    nop                 ; 1
    dec r17             ; 1
    brne bounce_loop    ; 2
    ; 192 cycles per iteration: 20us
    ; 74 iterations: 1.48ms
    reti
hit_10ms:
    nop
    ; 10ms has elapsed.
    ; +5 extra cycles to get here.
    ; Make PB0 go low:
    cbi PORTB, PB0
isr_exit:
    reti


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

    ; --- Configure timer for generating interrupts: ---

    ; Basically, this is what we do:
    ;   * Disable pin output from the timer/counter, so it only generates interrupts.
    ;   * Clock the timer/counter at a rate of CLK/256.
    ;   * Set a count limit of 75, with automatic clear; WGM = mode 2 (CTC).
    ;   * Make it fire an interrupt each time after 75 counts.

    ; Globally disable interrupts while we configure this...
    cli

    ; Set Timer/Counter Synchronization mode, locking the timer prescaler reset (section 12.4.1):
    ldi r16, 0b10000001     ; Set PSR10 (timer prescaler reset), and TSM (which keeps it locked).
    out GTCCR, r16

    ; Via TCCR0A:
    ; * Bits 7..6:  COM0A[1:0]              = 00 --> Disable "Compare Match Output" for OC0A.
    ; * Bits 5..4:  COM0B[1:0]              = 00 --> Disable "Compare Match Output" for OC0B.
    ; * Bits 1..0:  WGM[1:0] (2 LSBs of 3)  = 10 --> WGM[2:0] mode 2 (CTC), i.e. auto reset TC when it hits OCRA.
    ; See datasheet section 11.7.2 for more info on WGM CTC mode.
    ldi r16, 0b00000010
    out TCCR0A, r16

    ; Via TCCR0B, set:
    ; * Bit 3:      WGM's MSB (bit 2)                          = 0   --> WGM[2:0] mode 2 (CTC), as above.
    ; * Bits 2..0:  CS0[2:0] (Clock select for timer/counter)  = 100 --> Mode 4 (CLK/256).
    ; See datasheet sections 11.9.2 and 12.1 re CS (Clock select for timer/counter).
    ldi r16, 0b00000100
    out TCCR0B, r16

    ; Set OCR0A (i.e. trigger for counter interrupt):
    ; Since the clock source is CLK/256 (i.e. 37.5kHz), setting it to 75
    ; means OCF0A will be set at (37500/75) Hz => 500Hz => every 2ms. Hence,
    ; the ISR will fire every 2ms, and the ISR can then count the number of
    ; times it has fired to decide what to do at the 10ms and 14ms marks,
    ; respectively.
    ldi r16, 75
    out OCR0A, r16

    ; Enable the interrupt on OCF0A being set, but disable the rest:
    ldi r16, 0b00000100
    out TIMSK0, r16

    ; Make sure Timer/Counter is reset, right now:
    clr r16
    out TCNT0, r16

    ; TODO: Do we need to clear the TIFR0 (timer interrupt flags) register
    ; (by actually writing 1 to each bit)??

    ; All done; we can re-enable the prescaler and get the timer running:
    clr r16
    out GTCCR, r16

    ; We use r20 to count how many times the interrupt has fired.
    clr r20

    ; Globally enable interrupts.
    sei

sleep_loop:
    ; Enable sleep mode:
    in r16, MCUCR           ; Read current MCU Control Register state.
    ori r16, 0b00100000     ; Turn on SE (Sleep Enable) bit.
    andi r16, 0b11100111    ; Turn off SM1..0 bits to select "Idle" sleep mode.
    out MCUCR, r16          ; Update MCUCR.
    ; Sleep -- basically, halt the CPU and let interrupts fire when required:
    sleep
    ; I think we get here when a RETI occurs from within an ISR.
    rjmp sleep_loop
