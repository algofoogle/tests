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
    reti    ; Interrupt Vector 2   = EXT_INT0   (External Interrupt Request 0)
    reti    ; Interrupt Vector 3   = PCINT0     (Pin Change)
    reti    ; Interrupt Vector 4   = TIM0_OVF   (Timer Overflow)
    reti    ; Interrupt Vector 5   = EE_RDY     (EEPROM Ready)
    reti    ; Interrupt Vector 6   = ANA_COMP   (Analog Comparator)
    reti    ; Interrupt Vector 7   = TIM0_COMPA (Timer Compare Match A)
    reti    ; Interrupt Vector 8   = TIM0_COMPB (Timer Compare Match B)
    reti    ; Interrupt Vector 9   = WDT        (Watchdog Timeout)
    reti    ; Interrupt Vector 10  = ADC        (ADC Conversion Complete)



; Main program:
main:

    ; I've determined that an OSCCAL value of 0x6E gives the best approximation
    ; of 9.6MHz on my ATtiny13A.
    slide_osccal 0x6E

    disable_clock_prescaler

    ; --- Set up output ports ---
    ; Load value 0xFF directly into register R16. Each of bits 5..0,
    ; when set to 1, will configure that respective PORTB pin as
    ; an output (though only PB4..0 are usable in this case):
    ser r16
    ; Write R16 to DDRB, hence setting up all pins to be outputs.
    out DDRB, r16
    ; Synchronise:
    nop

    ; Set up PB0 to initially output a high value:
    sbi PORTB, PB0

loop:
    ; Initial delay is for 10ms, while PB0 is high.
    short_delay 10*16

    ; Toggle PB0 output: writing logic 1 to any output-mode bit of the
    ; PINB register will toggle the respective output pin.
    sbi PINB, PB0           ; 2 cycles.

    ; OK, PB0 should now be low. Keep it low for 4ms:
    short_delay 4*16

    ; Toggle PB0 to bring it high again:
    sbi PINB, PB0           ; 2 cycles.
    
    rjmp loop               ; 2 cycles.
