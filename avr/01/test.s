; Title::     Anton AVR test 01
; Author::    Anton Maurovic <anton.maurovic@gmail.com>
; URL::       http://anton.maurovic.com/
;             http://github.com/algofoogle/tests
;
; Description::
;
;     This is a very basic ATtiny13A test program in AVR Assembly language.
;
;     It is a very naive example of getting the MCU to do something... in this case
;     reading the state of PB3 (pin 2), and outputting its complement on PB4 (pin 3).
;     That is, when PB3 is low, PB4 is high.
;
;     All constants are defined in-line in this file.
;
; Burning info::
;
;     NOTE that when you burn this to an ATtiny13A, the following fuse bytes must
;     be used:
;
;         Low fuse byte:  should be 0x6A (MFR default):
;             Name        Bits    State   Meaning of State
;             SPIEN       7       0       SPI programming is ENABLED.
;             EESAVE      6       1       EEPROM will NOT be preserved during Chip Erase.
;             WDTON       5       1       Watchdog Timer is NOT on by default.
;             CKDIV8      4       0       Slow the clock during start-up: Divide it by 8.
;             SUT         3..2    10      Longest start-up time (64ms) to allow SPI intercept.
;             CKSEL       1..0    10      Use internal 9.6MHz clock.
;
;         High fuse byte: should be 0xFF (MFR default):
;             Name        Bits    State   Meaning of State
;             -           7..5    111     Reserved
;             SELFPRGEN   4       1       Self-programming is NOT enabled.
;             DWEN        3       1       debugWire is NOT enabled.
;             BODLEVEL    2..1    11      Brown-out detector is NOT enabled.
;             RSTDISBL    0       1       External reset is ENABLED.
;
;     Note that these bits use negative logic, i.e. when SPIEN=0, it means that
;     SPIEN *is* asserted, and hence SPI programming is ENABLED.
;
;     Given RSTDISBL=1, this "external reset disable" is NOT asserted and hence external
;     reset is ENABLED. This is important because:
;
;     *   In combination with CKDIV8 being asserted and SUT set to 64ms, there is plenty
;         of time for an AVR programmer (e.g. USBasp) to get in and start an SPI programming
;         handshake before the MCU starts executing its internal program.
;     *   If you "program" RSTDISBL (i.e. you set it to 0 instead of the default 1), then pin
;         1 of the ATtiny13A will no longer function as a RESET pin and instead will be a
;         regular I/O pin (specifically, PB5).
;     *   With the external RESET pin disabled, you can't re-program the chip with a basic
;         USBasp anymore, because the chip can't be held in the reset state. In this case
;         you'd need to use a "high voltage programmer".
;
;     Other fuse bytes are:
;
;         * Lock byte:    Usually 0xFF to indicate that nothing is locked.
;         * Calibration:  Usually pre-set by the MFR to the correct value.
;                         On my ATtiny13A, the value is 0x6D6D6D69, but it is
;                         likely to be different on yours.
;
; Usage info::
;
;     Under normal circumstances, for early tests, you want:
;
;     *   External RESET enabled (i.e. RSTDISBL=1);
;     *   Internal CLK enabled (i.e. CKSEL=10 for 9.6MHz clock).
;
;     ...which means that you can just wire up power to the chip and it should start
;     running normally after it has been programmed. You should also be able to
;     re-program it with the USBasp at will.


; ***    LOW fuse byte:  0x6A
; ***    HIGH fuse byte: 0xFF
; ***    EEPROM:         Not used


;;; ------- Constants -------

; Port B Data register:
; Standard IO port, accessing PB5..0 (i.e. 6 usable pins of DIP-8 ATtiny13A):
.equ PORTB, 0x18
; Port B Data Direction register:
; Any bit set to 0 defines an INPUT for the corresponding PORTB/PINB bit.
; Writing a 1 to a corresponding input bit of PORTB will enable the
; internal pull-up on the pin corresopnding to that bit.
.equ DDRB,  0x17
; Port B Input Pins address:
; Read the state of Port B's pins. Any defined as output should reflect
; their current driven state, while any defined as input should be
; sensed as expected.
.equ PINB,  0x16
; Bit numbers of PORTB pins. These are just for convenient references:
.equ PB0,   0
.equ PB1,   1
.equ PB2,   2
.equ PB3,   3
.equ PB4,   4
.equ PB5,   5
; Bit MASKS for PORTB pins:
.equ MPB0,  (1<<PB0)   ; 0b000001 => ATtiny13A pin 5
.equ MPB1,  (1<<PB1)   ; 0b000010 => ATtiny13A pin 6
.equ MPB2,  (1<<PB2)   ; 0b000100 => ATtiny13A pin 7
.equ MPB3,  (1<<PB3)   ; 0b001000 => ATtiny13A pin 2
.equ MPB4,  (1<<PB4)   ; 0b010000 => ATtiny13A pin 3
.equ MPB5,  (1<<PB5)   ; 0b100000 => ATtiny13A pin 1

; Interrupt table starts at 0x0000. ATtiny13A has 10 interrupt vectors (inc. RESET):
.org 0x0000
; Reset vector comes first:
    rjmp main
; The other 9 interrupts all go to the same ISR, at the moment:
    rjmp default_isr   ; Interrupt Vector 2   = EXT_INT0   (External Interrupt Request 0)
    rjmp default_isr   ; Interrupt Vector 3   = PCINT0     (Pin Change)
    rjmp default_isr   ; Interrupt Vector 4   = TIM0_OVF   (Timer Overflow)
    rjmp default_isr   ; Interrupt Vector 5   = EE_RDY     (EEPROM Ready)
    rjmp default_isr   ; Interrupt Vector 6   = ANA_COMP   (Analog Comparator)
    rjmp default_isr   ; Interrupt Vector 7   = TIM0_COMPA (Timer Compare Match A)
    rjmp default_isr   ; Interrupt Vector 8   = TIM0_COMPB (Timer Compare Match B)
    rjmp default_isr   ; Interrupt Vector 9   = WDT        (Watchdog Timeout)
    rjmp default_isr   ; Interrupt Vector 10  = ADC        (ADC Conversion Complete)

; The default ISR (Interrupt Service Routine) just returns:
default_isr:
    reti

; Main program:
main:
    ; Load value 0xF7 directly into register R16.
    ; This is going to be used to define PORTB in/out directions:
    ; NOTE: This could also be:
    ;   ldi r16, ~MPB3
    ; i.e. load r16 with the complement of the PB3 mask.
    ldi r16, 0b11110111     ; Bits 7..6 unused; PB3 is input; the rest are output.
    ; Write R16 to DDRB, hence setting up pin directions per respective bits:
    out DDRB, r16
    ; Turn on bit 3 of PORTB; since it is in INPUT mode, this means we turn on PB3's internal pull-up:
    ; Don't care about the state of the other pins, yet.
    sbi PORTB, PB3
    ; Wait for things to stabilise; may not really be necessary:
    nop

input_loop:
    ; Read from the inputs into r17:
    in r17, PINB            ; We OUT to PORTB (for 'control'), but IN from PINB (for 'sense').
    ; At this point, we neither care about, nor can predict, the state of any bit
    ; other than bit 3 (i.e. PINB3), as that is our input. If it is 0, then it is shorted
    ; to GND. If it is 1, then it is pulled high (either because it's left floating and
    ; pulled up internally, or because it's pulled high externally). Let's determine which...
    andi r17, MPB3          ; Mask to reveal only PB3.
    ; BRanch if EQual to pb3_low;
    ; i.e. if the result is zero, the Z flag is set, which is means "EQual".
    breq pb3_low            ; Go off and handle the state where PB3 is low.

    ; If we get here, it means PB3 is high...
    ; In this state, we want to turn OFF PB4:
    cbi PORTB, PB4          ; Clear bit 4 of PORTB, hence turning off PB4.
    ; Go back and repeat the input...
    rjmp input_loop

pb3_low:
    ; If we get here, it means PB3 is low...
    ; In this state, we want to turn ON PB4:
    sbi PORTB, PB4          ; Set bit 4 of PORTB, hence turning ON PB4.
    ; Go back and repeat the input...
    rjmp input_loop
