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

; =====	Local macros ===========================================================

.macro wait_for_nmi
	lda nmi_counter
:	cmp nmi_counter
	beq	:-				; Loop, so long as nmi_counter hasn't changed its value.
.endmacro

.macro nmi_delay frames
	lda #frames
	sta nmi_counter
:	lda nmi_counter
	bne :-
.endmacro



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
msg_ptr:		.res 1
screen_offset:	.res 1

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

hello_msg:
        ; 0123456789001234567890012345678901
	.byt "  Hello, World!                 "
	.byt "  This is a test by             "
	.byt "  anton@maurovic.com            "
	.byt "  - http://anton.maurovic.com", 0

; =====	Main code ==============================================================

.segment "CODE"


; NMI ISR.
; Use of .proc means labels are specific to this scope.
.proc nmi_isr
	dec nmi_counter
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
	; NOTE: There are 2 different ways to wait for VBLANK. This is one, recommended
	; during early startup init. The other is by the NMI being triggered.
	; For more information, see: http://wiki.nesdev.com/w/index.php/NMI#Caveats
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
	Repeat 4, inx
	bne :-
	; NOTE our DMA isn't triggered until a bit later on.

	; Wait for second VBLANK:
:	bit PPU_STATUS
	bpl :-
	; VLBANK asserted: PPU is now fully stabilised.

	; --- We're still in VBLANK for a short while, so do video prep now ---

	; Load the main palette.
	; $3F00-$3F1F in the PPU address space is where palette data is kept,
	; organised as 2 sets (background & sprite sets) of 4 palettes, each
	; being 4 bytes long (but only the upper 3 bytes of each being used).
	; That is 2(sets) x 4(palettes) x 3(colours). $3F00 itself is the
	; "backdrop" colour, or the universal background colour.
	ppu_addr $3F00	; Tell the PPU we want to access address $3F00 in its address space.
	ldx #0
:	lda palette_data,x
	sta PPU_DATA
	inx
	cpx #32		; P.C gets set if X>=M (i.e. X>=32).
	bcc :-		; Loop if P.C is clear.
	; NOTE: Trying to load the palette outside of VBLANK may lead to the colours being
	; rendered as pixels on the screen. See:
	; http://wiki.nesdev.com/w/index.php/Palette#The_background_palette_hack

	; Clear the first nametable.
	; Each nametable is 1024 bytes of memory, arranged as 32 columns by 30 rows of
	; tile references, for a total of 960 ($3C0) bytes. The remaining 64 bytes are
	; for the attribute table of that nametable.
	; Nametable 0 starts at PPU address $2000.
	; For more information, see: http://wiki.nesdev.com/w/index.php/Nametable
	; NOTE: In order to keep this loop tight (knowing we can only count up to
	; 255 in a single loop, rather than 960), we just have one loop and do
	; multiple writes in it.
	ppu_addr $2000
	lda #0
	ldx #32*30/4	; Only need to repeat a quarter of the time, since the loop writes 4 times.
:	Repeat 4, sta PPU_DATA
	dex
	bne :-

	; Clear attribute table.
	; One palette (out of the 4 background palettes available) may be assigned
	; per 2x2 group of tiles. The actual layout of the attribute table is a bit
	; funny. See here for more info: http://wiki.nesdev.com/w/index.php/PPU_attribute_tables
	ldx #64
	lda #$55			; Select palette 1 (2nd palette) throughout.
:	sta PPU_DATA
	dex
	bne :-

	; Activate VBLANK NMIs.
	lda #VBLANK_NMI
	sta PPU_CTRL

	; Now wait until nmi_counter increments, to indicate the next VBLANK.
	wait_for_nmi
	; By this point, we're in the 3rd VBLANK.

	; Trigger DMA to copy from local OAM_RAM ($0200-$02FF) to PPU OAM RAM.
	; For more info on DMA, see: http://wiki.nesdev.com/w/index.php/PPU_OAM#DMA
	lda #0
	sta PPU_OAM_ADDR	; Specify the target starts at $00 in the PPU's OAM RAM.
	lda #>OAM_RAM		; Get upper byte (i.e. page) of source RAM for DMA operation.
	sta OAM_DMA			; Trigger the DMA.
	; DMA will halt the CPU while it copies 256 bytes from $0200-$02FF
	; into $00-$FF of the PPU's OAM RAM.

	; Set X & Y scrolling positions (0-255 and 0-239 respectively):
	lda #0
	sta PPU_SCROLL		; Write X position first.
	sta PPU_SCROLL		; Then write Y position.

	; Configure PPU parameters/behaviour/table selection:
	lda #VBLANK_NMI|BG_0|SPR_0|NT_0|VRAM_RIGHT
	sta PPU_CTRL

	; Turn the screen on, by activating background and sprites:
	lda #BG_ON|SPR_ON
	sta PPU_MASK

	; Wait until the screen refreshes.
	wait_for_nmi
	; OK, at this point we know the screen is visible, ready, and waiting.

	; ------ Configure noise channel ------

	; Set volume control:
	; --0-----	Use silencing timer.
	; ---0----	Use volume envelope (fade).
	; ----0000	Envelope length (shortest).
	lda #%00000000		; Very short fade, one-shot.
	sta $400C			; Noise channel volume control.

	; Set noise type and period:
	; 0-------	Pseudo-random noise (instead of random regular waveform).
	; ----1000	Mid-range period/frequency.
	lda #%00001000
	sta $400E			; Noise mode & period (frequency).

	; Set length counter:
	; 11111---	Maximum timer (though other values seem to have no effect?)
	lda #%11111000
	sta $400F			; Length counter load.

	; Channel control:
	; ----1---	Enable noise channel.
	lda #%00001000
	sta $4015			; Channel control.


message_loop:
	; Wait 2s (120 frames at 60Hz):
	nmi_delay 60

	; Make a debug click by firing the noise channel one-shot
	; (by loading the length counter):
	lda #%00100000
	sta $400F

	; Clear the first 8 lines of the nametable:
	ppu_addr $2000
	lda #0
	ldx #(32*8/4)
:	Repeat 4, sta PPU_DATA
	dex
	bne :-

	; Point screen offset counter back to start of line 2:
	lda #(32*2)
	sta screen_offset

	; Point back to start of source message:
	lda #0
	sta msg_ptr

	; Fix scroll position:
	lda #0
	sta PPU_SCROLL		; Write X position first.
	sta PPU_SCROLL		; Then write Y position.

	; Wait 1s:
	nmi_delay 60

char_loop:
	; Fix message screen offset pointer:
	lda #$20	; Hi-byte of $2000
	sta PPU_ADDR
	lda screen_offset
	inc screen_offset
	sta PPU_ADDR

	; Fix scroll position:
	lda #0
	sta PPU_SCROLL		; Write X position first.
	sta PPU_SCROLL		; Then write Y position.

	; Write next character of message:
	ldx msg_ptr
	inc msg_ptr
	lda hello_msg,x
	beq message_done	; A=0 => End of message.
	sta PPU_DATA		; Write the character.

	cmp #$20
	beq no_click		; Don't make a click for space characters.

	; Activate short one-shot noise effect here, by loading length counter:
	lda #%00100000
	sta $400F

no_click:
	; Wait for 50ms (3 frames at 60Hz):
	nmi_delay 3
	jmp char_loop

message_done:
	nmi_delay 90
	; Scroll off screen.
	ldx #0
scroll_loop:
	cpx #((6*8)<<1)		; Scroll by 56 scanlines (7 lines), using lower 2 bits for counter.
	beq repeat_message_loop
	wait_for_nmi
	lda #0
	sta PPU_SCROLL		; X scroll is still 0.
	txa
	lsr a
	;lsr a
	sta PPU_SCROLL		; Y scroll is upper 6 bits of X.
	inx
	jmp scroll_loop

repeat_message_loop:
	jmp message_loop

.endproc



; =====	CHR-ROM Pattern Tables =================================================

; ----- Pattern Table 0 --------------------------------------------------------

.segment "PATTERN0"

	.incbin "anton.chr"

.segment "PATTERN1"

	.res $1000, $C1
	; Repeat the pattern table:
	;.incbin "anton.chr"
