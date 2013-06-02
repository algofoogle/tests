; This example makes use of nesfile.ini (i.e. a configuration file for ld65).

; Build this by running ./bb, which basically does this:
;	# Assemble:
;	ca65 test.s -o output/test.o -l
; 	# Link, to create test.nes:
;	ld65 output/test.o -m output/map.txt -o output/test.nes -C nesfile.ini
; ...and then runs it with FCEUX.

; =====	Includes ===============================================================

.include "nes.inc"		; This is found in cc65's "asminc" dir.
.include "nesdefs.inc"	; This may be better than "nes.inc".

; =====	iNES header ============================================================

.segment "INESHDR"
	.byt "NES",$1A
	.byt 1
	.byt 1

; =====	Interrupt vectors ======================================================

.segment "VECTORS"
	.addr nmi_isr, reset, irq_isr

; =====	Zero-page RAM ==========================================================

.segment "ZEROPAGE"

nmi_counter:	.res 1

; =====	General RAM ============================================================

.segment "BSS"
; Put labels with .res statements here.

; =====	Music ==================================================================

.segment "RODATA"

palette_data:
; Colours available in the NES palette are:
; http://bobrost.com/nes/files/NES_Palette.png
.repeat 2
	pal $09,	$16, $2A, $12	; $09 (dark plant green), $16 (red), $2A (green), $12 (blue).
	pal 		$16, $28, $3A	; $16 (red), $28 (yellow), $3A (very light green).
	pal 		$16, $28, $3A	; $16 (red), $28 (yellow), $3A (very light green).
	pal 		$16, $28, $3A	; $16 (red), $28 (yellow), $3A (very light green).
.endrepeat

; =====	Main code ==============================================================

.segment "CODE"


; NMI ISR.
; Use of .proc means labels are specific to this scope.
.proc nmi_isr
	inc nmi_counter
	rti
.endproc


; IRQ/BRK ISR:
.proc irq_isr
	; Handle IRQ/BRK here.
	rti
.endproc


; MAIN PROGRAM START: The 'reset' address.
.proc reset

	; Disable interrupts:
	sei

	; Basic init:
	ldx #0
	stx PPU_CTRL		; General init state; NMIs (bit 7) disabled.
	stx PPU_MASK		; Disable rendering, i.e. turn off background & sprites.
	stx APU_DMC_CTRL	; Disable DMC IRQ.

	; Set stack pointer:
	ldx $FF
	txs					; Stack pointer = $FF

	; Clear lingering interrupts since before reset:
	bit PPU_STATUS		; Ack VBLANK NMI (if one was left over after reset); bit 7.
	bit APU_CHAN_CTRL	; Ack DMC IRQ; bit 7

	; Init APU:
	lda #$40
	sta APU_FRAME		; Disable APU Frame IRQ
	lda #$0F
	sta APU_CHAN_CTRL	; Disable DMC, enable/init other channels.

	; PPU warm-up: Wait 1 full frame for the PPU to become stable, by watching VBLANK.
:	bit PPU_STATUS		; P.V (overflow) <- bit 6 (S0 hit); P.N (negative) <- bit 7 (VBLANK).
	bpl	:-				; Keep checking until bit 7 (VBLANK) is asserted.
	; First PPU frame has reached VBLANK.

	; Clear zeropage:
	ldx #0
	txa
:	sta $00,x
	inx
	bne :-

	; Disable 'decimal' mode.
	cld

	; Move all sprites below line 240, so they're hidden.
	; Here, we PREPARE this by loading $0200-$02FF with data that we will transfer,
	; via DMA, to the NES OAM (Object Attribute Memory) in the PPU. The DMA will take
	; place after we know the PPU is ready (i.e. after 2nd VBLANK).
	; NOTE: OAM RAM contains 64 sprite definitions, each described by 4 bytes:
	;	byte 0: Y position of the top of the sprite.
	;	byte 1: Tile number.
	;	byte 2: Attributes (inc. palette, priority, and flip).
	;	byte 3: X position of the left of the sprite.
	ldx #0
	lda #$FF
:	sta OAM_RAM,x	; Each 4th byte in OAM (e.g. $00, $04, $08, etc.) is the Y position.
	inx
	inx
	inx
	inx
	bne :-

	; Wait for second VBLANK:
:	bit PPU_STATUS
	bpl :-
	; VLBANK asserted: PPU is now fully stabilised.

	; --- We're still in VBLANK for a short while, so do video prep now ---

	; Load the main palette.
	; $3F00 is the 'universal background colour'. Each 4th byte after that is unused,
	; but the other 3 bytes are the colour indices for each of the 3 colours in 
	; each of 4 palettes, i.e. from $3F01-$3F0F.
	; This concept is then repeated for $3F10-$3F1F, for sprite colours.
	ppu_addr $3F00
	ldx #0
:	lda palette_data,x
	sta PPU_DATA
	inx
	cpx #32		; P.C gets set if X>=M (i.e. X>=32).
	bcc :-		; Loop if P.C is clear.

	; Clear the first nametable.
	; ...


	; NOTE: Trying to load the palette outside of VBLANK may lead to the colours being
	; rendered as pixels on the screen. See:
	; wiki.nesdev.com/w/index.php/Palette#The_background_palette_hack

main_loop:
	; Game code goes here.
	jmp main_loop
.endproc


; =====	CHR-ROM Pattern Tables =================================================

; ----- Pattern Table 0 --------------------------------------------------------

.segment "PATTERN0"

	.incbin "anton.chr"

.segment "PATTERN1"

	.res $1000, $C1
	; Repeat the pattern table:
	;.incbin "anton.chr"
