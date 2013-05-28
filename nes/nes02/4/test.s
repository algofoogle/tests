; Now we get access going to the whole NES CPU-address-space memory map.

; =============================== iNES HEADER ==========================================

.org $0000

.byt "NES",$1A			; Header magic.
.byt 1 					; 1 x PRG ROM chunk (16KiB).
.byt 1 					; 1 x CHR ROM chunk (8KiB).
.res (16-*), $00 		; Pad the rest of the header out to 16, with $00 as the filler.


; =============================== INTERNAL RAM ==========================================

; The NES has 2KiB of internal RAM, mapped as 000x_x###_####_####,
; i.e. where the upper 3 bits are 0, the lower 11 bits define the RAM address,
; and bits 11-12 are irrelevant. Hence, the RAM at $0000-$07FF is mirrored through
; $0800-$0FFF, then $1000-$17FF, and again at $1800-$1FFF.

.org $0000

internal_ram:

; NOTE: Addresses in the $0000-$00FF range lie in what's known as the 6502 "Zero Page".
; Special 6502 variants of common memory access instructions can access addresses in
; this range with less execution overhead.

zero_page:

; NOTE: The following variables merely define the addresses for space in the RAM
; that will be available at run-time, but which do not actually occupy space in this
; .nes file. Ideally these addresses should be reserved with a proper .segment later...

.enum
	delay_lo = 0	; Low byte of 16-bit counter.
	delay_hi		; High byte of 16-bit counter.
.endenum


; NOTE: The $0100-$01FF address range (i.e. "memory page $01") is available for the stack.
; That is, push/pull stack instructions, as well as JSR subroutines and interrupts
; all are hardwired to use this address range, based on the 8-bit address offset
; stored in the "S" stack pointer register.

.org $0100

stack:
	.org *+$0100

; More RAM follows here, from $0200-$07FF.

; =============================== NES PPU REGISTERS ==========================================

; The memory block 001x_xxxx_xxxx_x### belongs to the PPU. That is, there are 8 registers
; in the CPU space that interface with the PPU. These 8 registers are mirrored throughout the
; entire 2KiB memory block.
; I've implemented this as an enum, since it makes more sense:

.enum ppu
	control = $2000
	mask
	status
	oam_address
	oam_data
	scroll
	address
	data
.endenum

; =============================== NES APU and I/O REGISTERS ===============================

; The APU has 5 voices, each of which has 4 registers, starting at $4000:
;	$4000-$4003		Pulse 1:	Timer; length counter; envelope; sweep
;	$4004-$4007		Pulse 2:	Timer; length counter; envelope; sweep
;	$4008-$400B		Triangle:	Timer; length counter; linear counter
;	$400C-$400F		Noise:		Timer; length counter; envelope; linear feedback shift register
;	$4010-$4013		DMC (DPCM):	Timer; memory reader; sample buffer; output unit
; Additionally, these registers are used by voices:
;	$4015			Channel enable and length counter status
;	$4017			Frame counter

.enum apu
	pulse10 = $4000
	pulse11
	pulse12
	pulse13
	pulse20
	pulse21
	pulse22
	pulse23
	tri0
	tri1
	tri2
	tri3
	noise0
	noise1
	noise2
	noise3
	dmc0
	dmc1
	dmc2
	dmc3
	status = $4015
	frame = $4017
.endenum


; =============================== PRG ROM ==========================================



; PRG ROM size (defined above) is 16KiB, mapped to $C000-$FFFF.
.org $C000

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
	; Do init stuff.
	sei				; "SEt Interrupt disable"
	ldx #$ff		;
	txs				; Set stack pointer to $01FF (where the MSByte is implied).
	; Clear the zero page.
	ldx #0
	txa				; Transfer X to A
clear_zp:
	sta $00,x		; Set zero page offset $00+X to A (i.e. [X] <- 0).
	inx				; Increment X
	bne	clear_zp	; Not wrapped around to 0, yet?

	; Make a simple noise by telling the APU to activate a square wave (pulse) voice
	; at a particular frequency...
	lda #$01			; Bits 0 & 1, of register $4015, respectively enable Pulse voices 1 & 2.
	sta apu::status
	; We want a note at 440Hz ("A"). Our timer period is determined from frequency as:
	;	t = (CPU / (16 * f)) - 1
	; where CPU is 1,662,607 Hz for PAL, or 1,789,773 Hz for NTSC.
	; Hence, t = (1,789,773 / (16 * 440)) - 1 = 253.229
	; But, we can only go by integer values, so at t = 253, our frequency is:
	;	f = CPU / (16 * (t + 1)) = 1,789,773 / (16 * 254) = 440.4 Hz
	; ...which is only 1.6 'cents' off, and not discernable from 440Hz.
	; So, 253 in hex is $FD... Set the timer period to 000_1111_1101:
	lda #$fd
	sta apu::pulse12	; Timer low is $FD
	lda #$00
	sta apu::pulse13	; Timer high is $00
	; Now we set pulse10 ($4000) to $BF (1011_1111), which means:
	; 10......	; DD - Duty 2: 50%
	; ..1.....  ; L - Length counter halt.
	; ...1....  ; C - Constant volume.
	; ....1111	; VVVV - Actual volume: Maximum.
	lda #$bf
	sta apu::pulse10

	; Set up a counter to switch the Pulse 1 voice between 440Hz and ~888Hz
	; at a rate of ROUGHLY 14.3Hz.
	lda #0				; Init 16-bit counter to $0000...
	sta delay_lo		; ...
	sta delay_hi		; .
	lda #$fd			; Start off with a timer for 440Hz.

	; This loop produces a two-tone effect that is similar to a modern phone ringing:

sound_loop:
	dec delay_lo		; delay_lo starts at 0, decrements to $FF...
	bne sound_loop		; ...and until we hit 0 again, loop.
	; At this point, delay_lo has looped back to 0...
	dec delay_hi		; ...so we can decrement the high counter byte...
	bne	sound_loop		; ...and go thru another cycle.
	pha					; Save A for a sec.
	lda #$20			; Count down from $2000, not (effectively) $10000...
	sta delay_hi		; .
	pla					; Retrieve A.
	eor #$40			; Toggle bit 6 in A, to switch between $FD and $BD (440Hz (A) and 589Hz (D)).
	sta apu::pulse12	; Set timer length to adjusted 'A' value.
	jmp sound_loop


; ---------------= Interrupt Vectors =--------------------

; Pad out the PRG ROM to $FFF4, which is sort of where the 6502 interrupt vector table starts,
; though in actual fact that's for the 65C816. The 6502 only defines $FFFA (NMI) and above.
; See: http://en.wikipedia.org/wiki/Interrupts_in_65xx_processors
.res ($FFF4-*), $00

; We are now at $FFF4...
; NOTE: The labels here are irrelevant, really, but just make it clear what each
; vector actually is:
cop_vector:			; $FFF4
	.word $0000 	; (Unused)
brk_vector:			; $FFF6
	.word $0000 	; (Unused; actually a 65C816 vector)
abort_vector:		; $FFF8
	.word $0000 	; (Unused)
nmi_vector:			; $FFFA
	.word nmi_isr	; Address of the NMI ISR, defined near the start of the main PRG code in this case.
reset_vector:		; $FFFC
	.word reset		; Address of where to go after a reset; i.e. main program start.
irq_vector:			; $FFFE
	.word irq_isr	; Address of the IRQ/BRK ISR.



; =============================== CHR ROM ==========================================

; NOTE: Instead of putting the CHR ROM into this source file, you could just have it as
; a separate binary file (e.g. created with 'chromp') and then 'cat' it onto your .nes file,
; or otherwise include its raw binary data here with .incbin.

; The PPU (Picture Processing Unit) in the NES has its own address space
; (http://wiki.nesdev.com/w/index.php/PPU), in which $0000-$0FFF is "Pattern Table 0"
; (or the lower CHR bank), and $1000-$1FFF is "Pattern Table 1" (or the upper CHR bank),
; for a total of 8KiB of "pattern data".
; The cartridge typically maps this to CHR ROM or CHR RAM, and can map it to more than
; one bank by use of a 'mapper'.
; See http://wiki.nesdev.com/w/index.php/PPU_memory_map for more info.

; NOTE: Though I've defined a tile below, this probably won't be visible in any emulator
; by default, because I haven't set up the PPU (and palettes) in this code.

.org $0000

; Pattern Table 0:
.incbin "anton.chr"

; Pad out to 4KiB:
.res ($1000-*), $00

; Pattern Table 1:
.incbin "anton.chr"

; Pad out to 8KiB:
.res ($2000-*), $00
