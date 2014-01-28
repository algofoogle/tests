; This macro executes a delay measured in SIXTEENTHS OF A MILLISECOND
; (assuming that the system clock is 9.6MHz). It is called like this:
;   short_delay 160, r16, r17
; ...which would mean a delay of 10 millisecond (i.e. 160 x 1/16 = 10),
; and it uses registers r16 and r17 for its inner (A) and outer (B) loops,
; internally. The last 2 arguments are optional; they default to
; r16 and r17 if not specified.
;
; The minimum delay is "1", which is 1/16000 of a second.
; The maximum delay is "0", which is 256/16000 of a second => 16ms.
;
; I haven't implemented this as a subroutine: Calling it as a subroutine
; wouldn't save much over its current in-line size.
;
.macro short_delay ticks, reg_a=r16, reg_b=r17
    ; Outer "high" loop (multilpier):
    ldi \reg_b, \ticks      ; 1 cycle.
2:
    ldi \reg_a, 199         ; 1 cycle.
1:
    dec \reg_a              ; 1 cycle.
    brne 1b                 ; 1 cycle if zero, 2 cycles otherwise.
    ; The inner loop is done; now we run it again via our outer loop:
    dec \reg_b              ; 1 cycle.
    brne 2b                 ; 1 cycle if zero, 2 cycles otherwise.
.endm


; This is the same as short_delay, except it allows you to finely tune
; exactly how many cycles it will waste, by supplying values for
; both the inner and outer loops, such that the exact delay is:
; 	delay = (3*ticks_b*(ticks_a + 1) / 9600) milliseconds
; Examples:
;	; (3*16*200)/9600 => 1 millisecond:
; 		precise_delay 199, 16
;		; 6 instructions.
;	; Two cycles short of exactly 10 milliseconds:
;		precise_delay 134, 237	; 3*237*135 => 95985 cycles.
;		precise_delay   1, 2	; 3*2*2 => 12 cycles.
;		nop						; 1 cycle.
;		; SUM: 95,998 cycles => 2 less than 96,000.
;		; 13 instructions.
; NOTE: If ticks_a or ticks_b is 0, it's equivalent to 256.
; Examples:
;	precise_delay 1, 1		; Shortest possible delay: 3*1*2/9600 => 0.625us
;	precise_delay 0, 0		; Longest possible delay: 3*256*257/9600 => 20.56ms
.macro precise_delay ticks_a, ticks_b, reg_a=r16, reg_b=r17
    ; Outer "high" loop (multilpier):
    ldi \reg_b, \ticks_b    ; 1 cycle.
2:
    ldi \reg_a, \ticks_a    ; 1 cycle.
1:
    dec \reg_a              ; 1 cycle.
    brne 1b                 ; 1 cycle if zero, 2 cycles otherwise.
    ; The inner loop is done; now we run it again via our outer loop:
    dec \reg_b              ; 1 cycle.
    brne 2b                 ; 1 cycle if zero, 2 cycles otherwise.
.endm


; The code below "slides" OSCCAL to the target value, as the datasheet
; section 6.4.1 recommends.
.macro slide_osccal target
	in r16, OSCCAL
1:	; Loop start: Check calibration value.
	cpi r16, \target
	breq 3f				; Calibration matches target: Done!
	brlo 2f				; Calibration too low: Raise it.
	subi r16, 2			; Calibration too high: Lower it.
2:	; Jump here if calibration too low.
	inc r16
	out OSCCAL, r16		; Write new calibration value.
	rjmp 1b				; Go chcek it again.
3:	; Done!
.endm


; Ensure the Clock Pre-scaler is disabled (i.e. CLKPS is set to 0b0000)...
.macro disable_clock_prescaler
    ; First, enable writing to the CLKPS bits (CLKPR3..0):
    ldi r16, 0b10000000
    out CLKPR, r16
    ; Now, within 4 cycles, we must write our intended CLKPS value, which in
    ; this case is still 0b0000. When performing this write, we must also write
    ; 0 to CLKPCE:
    ldi r16, 0b00000000     ; Cycle 1
    out CLKPR, r16          ; Cycle 2
    ; The CPU clock should be running at full speed now (9.6MHz).
.endm
