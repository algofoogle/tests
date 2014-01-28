; Title::     Anton AVR test 04
; Author::    Anton Maurovic <anton.maurovic@gmail.com>
; URL::       http://anton.maurovic.com/
;             http://github.com/algofoogle/tests
;
; Description::
;
;     This is a very basic ATtiny13A test program in AVR Assembly language.
;
;     It slides the OSCCAL value from its power-on default to a value (0x6E)
;     that I've determined to be more-accurate for trying to hit 9.6MHz.
;
;     It then disables the clock prescaler so the clock runs at the full 9.6MHz.
;     (rather than 1.2MHz).
;
;     Finally it configures PB4..0 as outputs and toggles PB0 at a frequency
;     that is 1/4 of the system clock. PB1 toggles at half that frequency,
;     PB2 at half that again, and so-on. This is used for determining
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
; Port B Input Register:
; When pins of PORTB are configured for OUTPUT, writing a logic 1 to any
; bit in this register will actually cause the output to toggle from its
; current state. This can be done, for instance, with the SBI instruction:
.equ PINB,  0x16
; OSCCAL gets loaded with the clock calibration value at RESET, but we can
; override it. Increasing it (up to a limit of 0x7F) will speed up the clock.
.equ OSCCAL, 0x31
; CLKPR is the Clock Prescaler Register and is used to divide the clock before
; it reaches the CPU. By default, this is set to 0b0011 because of the CKDIV8
; fuse bit, but we'll override it to 0b0000 which means the clock will run
; at full speed.
.equ CLKPR, 0x26
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


; This macro executes a delay measured in SIXTEENTHS OF A MILLISECOND
; (assuming that the system clock is 9.6MHz). It is called like this:
;   short_delay 160, r16, r17
; ...which would mean a delay of 10 millisecond (i.e. 160 x 1/16 = 10),
; and it uses registers r16 and r17 for its inner (A) and outer (B) loops,
; internally.
;
; The minimum delay is "1", which is 1/16000 of a second.
; The maximum delay is "0", which is 256/16000 of a second => 16ms.
;
; The macro works as follows:
;
; There are two loops to waste cycles. The inner one will execute
; in exactly 3*A cycles, for the value that A gets set to internally.
; The outer loop will execute the inner loop B times, plus it has its own
; overhead of 3*B cycles.
;
; Hence, we can calculate the total delay as:
;   delay = (3*A)*B + 3*B
;         = B * (3*A + 3)
;         = 3*B*(A + 1)
;
; NOTE: If A or B are set to 0, their respective loop will run 256 iterations,
; since the loop decrement is done BEFORE comparing to 0.
;
; With the macro's built-in 'A' value of 199, we can say that the delay will be:
;   delay = 3*B*200 cycles
; ...which at 9.6MHz is:
;   delay = 600*B / 9600000 = B / 16000 seconds.
; Hence, if the delay value is 16:
;   delay = 16 / 16000 = 1/1000 second = 1 millisecond.
;
.macro short_delay ticks, reg_a=r16, reg_b=r17
    ; Outer "high" loop (multilpier):
    ldi \reg_b, \ticks            ; 1 cycle.
2:
    ; Inner "high" loop:
    ; The inner loop (high1) takes 3*R16 cycles to execute, for any given
    ; value of R16. This is determined as follows:
    ;   Initial R16 load:               1 cycle;
    ; + (
    ;       R16 decrement:              1 cycle;
    ;       Branch while R16 non-zero:  2 cycles;
    ;   )
    ; + Final R16 decrement:            1 cycle;
    ; + Final SKIP branch:              1 cycle;
    ; Hence if R16 starts at 255, it will spend 765 cycles.
    ; This is 765/9,600,000 of a second => 79.6875us.
    ldi \reg_a, 199         ; 1 cycle.
1:
    dec \reg_a              ; 1 cycle.
    brne 1b                 ; 1 cycle if zero, 2 cycles otherwise.
    ; The inner loop is done; now we run it again via our outer loop:
    dec \reg_b              ; 1 cycle.
    brne 2b                 ; 1 cycle if zero, 2 cycles otherwise.
.endm


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

; --- CLOCK CALIBRATION ---
    ; I've determined that an OSCCAL value of 0x6E gives the best approximation
    ; of 9.6MHz on my ATtiny13A.

    ; The code below "slides" OSCCAL to the target value, as the datasheet
    ; section 6.4.1 recommends.

    ; Set R17 to our target OSCCAL value:
    ldi r17, 0x6E
    ; Read current OSCCAL value.
    in r16, OSCCAL
cal_loop:
    out OSCCAL, r16
    ; Compare current OSCCAL value with target:
    cp r16, r17
    ; If they're equal, we're done...
    breq calibration_done
    ; If r16 is lower than r17, then step it up.
    brlo cal_up
    ; OK, r16 is greater than r17, so step it down.
    dec r16
    rjmp cal_loop
cal_up:
    inc r16
    rjmp cal_loop
calibration_done:

; --- DISABLE CLOCK PRE-SCALER ---
    ; Ensure the Clock Pre-scaler is disabled (i.e. CLKPS is set to 0b0000)...

    ; First, enable writing to the CLKPS bits (CLKPR3..0):
    ldi r16, 0b10000000
    out CLKPR, r16
    ; Now, within 4 cycles, we must write our intended CLKPS value, which in
    ; this case is still 0b0000. When performing this write, we must also write
    ; 0 to CLKPCE:
    ldi r16, 0b00000000     ; Cycle 1
    out CLKPR, r16          ; Cycle 2
    ; The CPU clock should be running at full speed now (9.6MHz).

; --- Set up output ports ---
    ; Load value 0xFF directly into register R16. Each of bits
    ; 5..0, when set to 1, will configure that respective PORTB pin as
    ; an output (though only PB4..0 are usable in this case):
    ldi r16, 0xFF
    ; Write R16 to DDRB, hence setting up all pins to be outputs.
    out DDRB, r16
    ; NOP lets the system synchronise:
    nop

    ; Set up PB0 to initially output a high value:
    sbi PORTB, PB0

loop:
    ; Initial delay is for 10ms, while PB0 is high.
    ; Delay duration is expressed in SIXTEENTHS of a millisecond,
    ; so 160 => 10ms. 'r16' and 'r17' are the registers we nominate
    ; to use internally for the count-down loops.
    short_delay 10*16

    ; Toggle PB0 output: according to section 10.2.2 of the datasheet,
    ; writing a logic 1 to any bit of the PINB register -- where it is
    ; configured for output -- will cause the respective output pin
    ; to toggle its state.
    sbi PINB, PB0           ; 2 cycles.

    ; OK, PB0 should now be low. Keep it low for 4ms:
    short_delay 4*16

    ; Toggle PB0 to bring it high again:
    sbi PINB, PB0           ; 2 cycles.
    
    rjmp loop               ; 2 cycles.
