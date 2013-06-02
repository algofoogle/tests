; This example makes use of nesfile.ini (i.e. a configuration file for ld65),
; by using it to define segments, memory ranges, and the layout of the output
; .nes file. By doing it this way, we no longer need to explicitly define the
; perfect binary laytout of the target .nes file. We can focus instead on
; defining the content intended for specific segments, and let the linker
; (ld65) take care of actually arranging it into the correct binary footprint.

; Build this by running ./bb, which basically does this:
;	# Assemble:
;	ca65 test.s -o output/test.o -l
; 	# Link, to create test.nes:
;	ld65 output/test.o -m output/map.txt -o output/test.nes -C nesfile.ini
; ...and then runs it with FCEUX.

; =====	Includes ===============================================================

.include "nes.inc"		; This is found in cc65's "asminc" dir, and defines lots of NES hardware stuff.
.include "music.inc"	; Macro to generate musical notes as a set of APU Pulse timers.

; =====	iNES header ============================================================

.segment "INESHDR"
	.byt "NES",$1A
	.byt 1
	.byt 1

; =====	Interrupt vectors ======================================================

.segment "VECTORS"
	; 3 WORDs expected; addresses of the NMI ISR, Reset point, and IRQ/BRK ISR respectively.
	.addr nmi_isr, reset, irq_isr

; =====	General RAM ============================================================

.segment "BSS"

; 16-bit counter for the dumb delay timer:
delay_lo:	.res 1
delay_hi:	.res 1

; =====	Music ==================================================================

.segment "RODATA"

music:
	; Musical data for "Minuet in G major":
	; http://en.wikipedia.org/wiki/Minuet_in_G_major_%28BWV_Anh._114%29
	; See "music.inc" for the 'Notes' declaration.
	Notes "G4 __ C4 D4 E4 F4 G4 __ C4 __ C4 __ A4 __ F4 G4 A4 B4 C5 __ C4 __ C4 __ "
	Notes "F4 __ G4 F4 E4 D4 E4 __ F4 E4 D4 C4 B3 __ C4 D4 E4 C4 E4 __ D4 __ __ __ "
	Notes "G4 __ C4 D4 E4 F4 G4 __ C4 __ C4 __ A4 __ F4 G4 A4 B4 C5 __ C4 __ C4 __ "
	Notes "F4 __ G4 F4 E4 D4 E4 __ F4 E4 D4 C4 D4 __ E4 D4 C4 B3 C4 __ __ __ __ __ "
	.byt $FF

; =====	Main code ==============================================================

.segment "CODE"

; ISR (Interrupt Service Routine) for the NMI:
nmi_isr:
	; Handle NMI here.
	rti

; ISR for the IRQ/BRK interrupt:
irq_isr:
	; Handle IRQ/BRK here.
	rti

; MAIN PROGRAM START: The 'reset' address (referenced by the Interrupt Vectors table, later on).
reset:
	; Disable interrupts:
	sei
	; Set up stack to point to $FF in page $01 (i.e. $01FF):
	ldx #$ff
	txs
	; Clear zeropage:
	ldx #0
	txa
:	sta $00,x
	inx
	bne :-
	; Turn on APU Pulse 1:
	lda #$01
	sta APU_CHANCTRL
	; Set Pulse 1 timer to $3FF (1023), which gives a frequency of:
	;	f	= CpuMhz / (16 * (t + 1))
	;		= 1,789,773 / (16 * 1024) = 109Hz (Approx A2)
	lda #$ff
	sta APU_PULSE1FTUNE
	lda #$03
	sta APU_PULSE1CTUNE
	; Set Pulse 1 characteristics:
	lda #$bf
	sta APU_PULSE1CTRL
	; Reset music counters, etc.
	lda #0
	sta delay_lo
	sta delay_hi
music_score_loop:
	ldx #0
music_note_loop:
	lda #$80	; This sets the tempo. Lower is faster.
	sta delay_hi
	; Load a note:
	lda music,x	; A holds high-byte of timer.
	inx
	cmp #$FF	; Hit EOF?
	beq music_score_loop	; If so, loop.
; Delay loop:
:	dec delay_lo
	bne :-
	dec delay_hi
	bne :-
	cmp #$FE	; Rest?
	beq next_note			; If so, don't change APU registers.
	sta APU_PULSE1CTUNE		; Store high 3 bits of timer.
	lda music,x
	sta APU_PULSE1FTUNE		; Store low 8 bits of timer.
next_note:
	inx
	jmp music_note_loop


; =====	CHR-ROM Pattern Tables =================================================

; ----- Pattern Table 0 --------------------------------------------------------

.segment "PATTERN0"

	.res $1000, $C0
	;.incbin "anton.chr"

.segment "PATTERN1"

	.res $1000, $C1
	; Repeat the pattern table:
	;.incbin "anton.chr"
