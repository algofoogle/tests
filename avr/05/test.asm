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

; This is an ISR (Interrupt Service Routine) that handles TIM0_COMPA
; (i.e. interrupt generated when when Timer/Counter 0 hits a given limit
; in OCR0A). This is currently configured to fire every 2ms.
; 
; This ISR keeps track of how many times it has fired (in R20).
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
    ; NOTE: I count cycles here so I know that, no matter which path
    ; this ISR takes, any I/O events can be timed to occur exactly
    ; the same number of cycles after the event fired. This allows us
    ; to get precisely-synchronised pin outputs, for example.
    inc r20                     ; 1 cycle -- Increment interrupt counter.
    ; Check if this the first interrupt of the sequence, and if so
    ; go do some work in the 2ms window we have.
    cpi r20, 1                  ; 1 cycle -- First hit?
    breq _timer_isr_do_work     ; 1 cycle (if R20!=1) or 2 cycles (if R20==1).
                                ; (4 cycles elapsed when entering _timer_isr_do_work)
    ; Check if this is the 5th interrupt. If so, 10ms has elapsed.
    cpi r20, 5                  ; 1 cycle -- 5th hit?
    breq _timer_isr_10ms        ; 1 cycle (if R20!=5) or 2 cycles (if R20==5).
                                ; (6 cycles elapsed when entering _timer_isr_10ms)
    ; Check if this is the 7th interrupt. If so, 14ms elapsed, and end of sequence.
    cpi r20, 7                  ; 1 cycle -- 7th hit?
    brne _timer_isr_exit        ; 1 cycle (if R20==7), don't care otherwise.

    ; 14ms total has elapsed...
    ; +7 extra cycles.
    ; Bring PB0 back up high, while we start another cycle.
    sbi PORTB, PB0
    ; Reset interrupt counter:
    clr r20
    ; Exit ISR:
    reti

_timer_isr_do_work:
    nop                         ; 1 cycle...
    nop                         ; 1 cycle...
    nop                         ; 1 cycle -- SYNC.
    ; 2ms has elapsed...
    ; +7 extra cycles.
    ; Do some "work" at this point, as a proof-of-concept.
    ; In this case, 'bounce' PB1 around, making it toggle an even number of times...
    ; The _timer_isr_toggle_loop is 480 cycles (50us) per iteration,
    ; and R19 makes it go for 30 iterations. This makes it take 1.5ms.
    ; Since there are TWO transitions (of 50us each) per waveform cycle, this is a
    ; waveform period of 100us, or a frequency of 10kHz.
    ;
    ldi r19, 30                 ; NOTE: This could replace one of the NOPs above.
_timer_isr_toggle_loop:
    sbi PINB, PB1               ; 1 cycle -- Toggle PB1.
    ; Delay for 476 cycles...
    precise_delay 1, 79         ; 474 cycles -- Formula is: (1+1)*79*3
    nop                         ; 1 cycle.
    nop                         ; 1 cycle.
    ; ...476 cycles.
    dec r19                     ; 1 cycle.
    brne _timer_isr_toggle_loop ; 1 or 2 cycles.
    ; DONE: Exit the ISR:
    reti

_timer_isr_10ms:
    nop                         ; 1 cycle -- SYNC.
    ; 10ms has elapsed...
    ; +7 extra cycles.
    ; Make PB0 go low.
    cbi PORTB, PB0

_timer_isr_exit:
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
    
