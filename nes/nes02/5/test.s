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

; =====	Includes ===============================================================

.include "nes.inc"	; This is found in cc65's "asminc" dir, and defines lots of NES hardware stuff.


; =====	iNES header ============================================================

.segment "INESHDR"
	.byt "NES",$1A
	.byt 1
	.byt 1

; =====	Interrupt vectors ======================================================

.segment "VECTORS"
	.addr nmi_isr, reset, irq_isr

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
	; Set Pulse 1 timer to $FD (253), which gives a frequency of:
	;	f	= CpuMhz / (16 * (t + 1))
	;		= 1,789,773 / (16 * 254) = 440.4Hz ('A').
	lda #$fd
	sta APU_PULSE1FTUNE
	lda #$00
	sta APU_PULSE1CTUNE
	; Set Pulse 1 characteristics:
	lda #$bf
	sta APU_PULSE1CTRL

	; Freeze:
	jmp *


; =====	CHR-ROM Pattern Tables =================================================

; ----- Pattern Table 0 --------------------------------------------------------

.segment "PATTERN0"

	.res $1000, $C0
	;.incbin "anton.chr"

.segment "PATTERN1"

	; Repeat the pattern table:
	;.incbin "anton.chr"
	.res $1000, $C1
