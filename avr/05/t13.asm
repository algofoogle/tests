;;; ------- Constants -------

.equ PORTB, 0x18
.equ DDRB,  0x17
.equ PINB,  0x16
.equ OSCCAL, 0x31
.equ CLKPR, 0x26
; Bit numbers of PORTB pins.
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


