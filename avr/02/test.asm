; Title::     Anton AVR test 02
; Author::    Anton Maurovic <anton.maurovic@gmail.com>
; URL::       http://anton.maurovic.com/
;             http://github.com/algofoogle/tests
;
; Description::
;
;     This is a very basic ATtiny13A test program in AVR Assembly language.
;
;     It configures PB4..0 as outputs and toggles PB0 at a fundamental frequency
;     relative to the system clock, then PB1 at half that frequency, PB2
;     at half the rate of PB1, and so-on. This is used for determining
;     the system clock of the MCU, given a known number of CPU cycles
;     counted out per each instruction in this source file.
;
;     All constants are defined in-line in this file.
;
; Burning info::
;
; ***    LOW fuse byte:  0x6A
; ***    HIGH fuse byte: 0xFF
; ***    EEPROM:         Not used
;
; Usage info::
;
;     Under normal circumstances, for early tests, you want the following characteristics
;     which are set by the fuse byte values given in the 'Burning info':
;
;     *   External RESET enabled (i.e. RSTDISBL=1);
;     *   Internal CLK enabled (i.e. CKSEL=10 for 9.6MHz clock).
;
;     ...which means that you can just wire up power to the chip and it should start
;     running normally after it has been programmed. You should also be able to
;     re-program it with the USBasp at will.


;;; ------- Constants -------

; Port B Data register:
; Standard IO port, accessing PB5..0 (i.e. up to 6 usable pins of DIP-8 ATtiny13A):
.equ PORTB, 0x18
; Port B Data Direction register:
; Any bit set to 0 defines an INPUT for the corresponding PORTB/PINB bit.
; In this example, however, we'll configure all of them as outputs
; (though only PB4..0 will be usable since PB5's pin 1 will be configured
; as the External /RESET).
.equ DDRB,  0x17

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
    ; Load value 0xFF directly into register R16. Each of bits
    ; 5..0, when set to 1, will configure that respective PORTB pin as
    ; an output (though only PB4..0 are usable in this case):
    ldi r16, 0xFF
    ; Write R16 to DDRB, hence setting up all pins to be outputs.
    out DDRB, r16
    ; NOP lets the system synchronise:
    nop

    ; Now load R16 with 0; it will be our counter whose value we write
    ; to PORTB to cause it to toggle all pins:
    ldi r16, 0

    ; The rest here is cycle-counted so we can figure out exactly what rate
    ; it will run at:
loop:
    ; Write counter state to pins:
    out PORTB, r16          ; 1 cycle.
    ; Increment r16, causing cascading toggles to occur:
    inc r16                 ; 1 cycle.
    ; Repeat the loop:
    rjmp loop               ; 2 cycles.

; HENCE: One iteration of the loop is 4 cycles, so PB0 (our Reference)
; will TRANSITION from 0 to 1, or 1 to 0, at (CLK/4) Hz, or rather
; will produce a frequency of (CLK/8) Hz (since frequency is determined
; by the length of one full cycle, and one full cycle is the time
; it takes to transition TWICE).

; So, for different CLK speeds:
;
;    | CLK     | PB0 freq | PB4 freq |
;    |---------|----------|----------|
; 1. | 9.6MHz  | 1.2MHz   | 75kHz    |
; 2. | 1.2MHz  | 150kHz   | 9375Hz   |
;
; ...where speed 1 (9.6MHz) is the default internal RC oscillator running
; at full speed, and speed 2 (1.2MHz) is that same speed divided by 8,
; i.e. if CKDIV8 is in effect and NOT otherwise disabled in code.
