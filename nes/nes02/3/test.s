; This example builds on the skeleton .nes file structure defined in nes02/2,
; by introducing a couple of CHR ROM tiles, and some minimal functioning PRG code
; (in this case, just an endless loop).

; =============================== iNES HEADER ==========================================

; First we create the iNES header, which we will assume can be said to start at $0000:
.org $0000

; ...and the following iNES header defines a .nes file which is expected to have the following
; binary layout:
;	1.	0x0000-0x000F:	Header (16 bytes).
;	2.	0x0010-0x400F:	PRG ROM (one PRG chunk; 16KiB).
;	3.	0x4010-0x600F:	CHR ROM (one CHR chunk; 8KiB).

.byt "NES",$1A			; Header magic.
.byt 1 					; Specify that we have only 1 x PRG ROM chunk (16KiB).
.byt 1 					; ...and only 1 x CHR ROM chunk (8KiB).
.byt %00000000			; 'Flags 6' bits.
.byt %00000000			; 'Flags 7' bits.
.byt 0 					; We have 0 x 8KiB chunks of PRG RAM, though apparently this actually
						; infers that we have 1 x 8KiB chunk.
						; See http://wiki.nesdev.com/w/index.php/PRG_RAM_circuit for more info.
.byt %00000000 			; 'Flags 9' bits.
.byt %00000000			; 'Flags 10' bits.
.res (16-*), $00 		; Pad the rest of the header out to 16, with $00 as the filler.

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
	; Make a simple noise by selecting a square wave voice and defining the period
	; of that wave (in this case $01F0). This sound is then emitted endlessly by the
	; APU, until otherwise instructed, regardless of what else the CPU is doing
	; (which in this case, will be executing an endless loop at 'forever').
	lda #$01 		; Square 1
	sta $4015
	lda #$F0		; period (LSByte)
	sta $4002
	lda #$01		; period (MSByte)
	sta $4003
	lda #$bf		; volume
	sta $4000

forever:
	nop
	jmp forever		; Loop endlessly.

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

; Pattern Table 0:
.org $0000

.byt %10000001
.byt %01000010
.byt %00100100
.byt %00011000
.byt %00011000
.byt %00100100
.byt %01000010
.byt %10000001

.byt %00010000
.byt %00010000
.byt %00010000
.byt %11111111
.byt %00010000
.byt %00010000
.byt %00010000
.byt %00010000

; Pad out to 4KiB:
.res ($1000-*), $00

; Pattern Table 1:
	;;;;;;;;;;;;;;
	;; PATTERN TABLE 0 DATA GOES HERE
	;;;;;;;;;;;;;;

; Pad out to 8KiB:
.res ($2000-*), $00
