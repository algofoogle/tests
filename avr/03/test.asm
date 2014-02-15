; Title::     Anton AVR test 03
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
; OSCCAL gets loaded with the clock calibration value at RESET, but we can
; override it. Increasing it (up to a limit of 0x7F) will speed up the clock.
.equ OSCCAL, 0x31
; CLKPR is the Clock Prescaler Register and is used to divide the clock before
; it reaches the CPU. By default, this is set to 0b0011 because of the CKDIV8
; fuse bit, but we'll override it to 0b0000 which means the clock will run
; at full speed.
.equ CLKPR, 0x26

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
    ; The MFR-set calibration value on my ATtiny13, for 9.6MHz mode, is 0x69.
    ; During power-on it automatically loads this into OSCCAL to adjust the
    ; built-in clock speed. According to the datasheet (section 6.4.1),
    ; higher values (up to 0x7F) will result in a higher internal clock speed.

    ; From testing, I found that the ideal value for my ATtiny13A in current
    ; temperature conditions was 0x6E, which adjusts the factory clock speed
    ; from about 8.8MHz (8% error) to 9.7MHz (1%) error.

    ; The code below "slides" OSCCAL to the target value rather than jumping
    ; there directly, as changing OSCCAL by too much in one go may cause
    ; problems, according to the datasheet:
    ;   To ensure stable operation of the MCU the calibration value should be
    ;   changed in small steps. A variation in frequency of more than 2% from
    ;   one cycle to the next can lead to unpredicatble behavior. Changes in
    ;   OSCCAL should not exceed 0x20 for each calibration

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
    ; I have the CKDIV8 fuse bit 'programmed' on my device, which means the clock
    ; will be divided by 8 from power-on. We can disable this by changing the
    ; "System CLock Prescaler" according to section 6.3 of the datasheet.
    ; To do this, we write to CLKPR, which has a special procedure...

    ; First, enable writing to the CLKPS bits (CLKPR3..0) by writing 0 to them,
    ; along with 1 written to the CLKPCE enable bit (CLKPR7):
    ldi r16, 0b10000000
    out CLKPR, r16
    ; Now, within 4 cycles, we must write our intended CLKPS value, which in
    ; this case is still 0b0000. When performing this write, we must also write
    ; 0 to CLKPCE:
    ldi r16, 0b00000000     ; Cycle 1
    out CLKPR, r16          ; Cycle 2
    ;nop                     ; Cycle 3
    ;nop                     ; Cycle 4

    ; ...and we're done. The CPU clock should be running at full speed now (9.6MHz),
    ; and hence the code below should produce a 1.2MHz square wave on PB0.

; --- Set up output ports ---
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
; will produce a FREQUENCY of (CLK/8) Hz (since frequency is determined
; by the length of one full cycle, and one full cycle is the time
; it takes to transition TWICE).

; So, given the clock has been configured to run at the full 9.6MHz,
; then if it is calibrated properly, we should see these frequencies
; at the pins of the MCU:
;
;    | PB0     | PB1      | PB2      | PB3      | PB4      |
;    | Pin 5   | Pin 6    | Pin 7    | Pin 2    | Pin 3    |
;    |---------|----------|----------|----------|----------|
;    | 1.2MHz  | 600kHz   | 300kHz   | 150kHz   | 75kHz    |
;
