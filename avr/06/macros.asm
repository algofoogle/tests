
; Set up the stack pointer, by default to the top of SRAM (i.e. RAMEND):
.macro init_stack addr=RAMEND
    .ifdef SPH
        ; We're on an architecture that has the SPH register.
        ldi r16, hi8(\addr)
        out SPH, r16
    .elseif \addr > 0xFF
        ; ERROR: We were given a WORD-sized stack pointer address, but
        ; this architecture has no SPH register, so it will only accept
        ; a BYTE-sized stack pointer address:
        .error "Stack pointer address exceeds this architecture's limit!"
    .endif
    ldi r16, lo8(\addr)
    out SPL, r16
.endm

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
.macro short_delay ticks:req, reg_a=r16, reg_b=r17
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
.macro precise_delay ticks_a:req, ticks_b:req, reg_a=r16, reg_b=r17
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
.macro slide_osccal target:req
	in r16, OSCCAL
1:	; Loop start: Check calibration value.
	cpi r16, \target
	breq 3f				; Calibration matches target: Done!
	brlo 2f				; Calibration too low: Raise it.
    ; To shave instructions, the logic here is basically:
    ;    OSCCAL += (too_high ? -2 : 0) + 1
    ; => OSCCAL += (too_high ? -1 : 1)
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


; This initialises a simple timer that fires the TIM0_COMPA interrupt
; after a given number of timer counts ("threshold"). It should be used
; like this:
;   init_simple_timer csmode, [t], [r]
;   ...where csmode is one of:
;       clk_1       = CS0 mode 1 (no prescaler -- full speed timer clock).
;       clk_8       = CS0 mode 2 (CLK/8 prescaler).
;       clk_64      = CS0 mode 3 (CLK/64 prescaler).
;       clk_256     = CS0 mode 4 (CLK/256 prescaler).
;       clk_1024    = CS0 mode 5 (CLK/1024 prescaler).
;       clk_xfall   = CS0 mode 6 (External T0 clock, falling edge).
;       clk_xrise   = CS0 mode 7 (External T0 clock, rising edge).
;   ...and t:
;       * If omitted, use the threshold pre-set in r17.
;       * If "reg", use the threshold pre-set in register \r.
;       * If anything else, use that constant as the threshold.
.equ clk_1,     1
.equ clk_8,     2
.equ clk_64,    3
.equ clk_256,   4
.equ clk_1024,  5
.equ clk_xfall, 6
.equ clk_xrise, 7
.macro init_simple_timer csmode:req, t, r
    ; Disable interrupts:
    cli
    ; Set TC sync mode; i.e. lock the timer's reset line.
    ldi r16, 0b10000001
    out GTCCR, r16
    ; Disable automatic output of the timer on the MCU's external pins,
    ; and select CTC (WGM mode 2) to auto-clear timer when it hits \threshold.
    ldi r16, 0b00000010
    out TCCR0A, r16
    ldi r16, \csmode    ; Set Clock Source mode in bits 2..0.
    out TCCR0B, r16
    ; Set OCR0A (counter limit, and trigger point for counter interrupt):
    .ifb \t
        ; \t is blank, so just use value in r17:
        out OCR0A, r17
    .else
        .ifc \t, reg
            ; We expect a register as the source, in \r:
            out OCR0A, \r
        .else
            ; Constant given:
            ldi r16, \t
            out OCR0A, r16
        .endif
    .endif
    ; Enable the interrupt on OCF0A being set, but disable the rest:
    ldi r16, 0b00000100
    out TIMSK0, r16
    ; Reset timer value:
    clr r16
    out TCNT0, r16
    ; Re-enable the prescaler and get the timer running:
    out GTCCR, r16
    ; Globally enable interrupts:
    sei
.endm

; This enables a given SLEEP mode. Default (if not specified)
; is CPU Idle mode (0).
.equ sleep_idle,        0b00
.equ sleep_adc,         0b01    ; ADC Noise Reduction mode.
.equ sleep_powerdown,   0b10
.macro enable_sleep mode=sleep_idle
    in r16, MCUCR           ; Read current MCU Control Register state.
    ori r16, 0b00100000     ; Turn on SE (Sleep Enable) bit.
    andi r16, 0b11100111    ; Turn off SM1..0 bits to select "Idle" sleep mode.
    out MCUCR, r16          ; Update MCUCR.
.endm
