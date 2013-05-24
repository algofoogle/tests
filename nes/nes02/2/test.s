; In this example, I will start assembling a skeleton iNES-compatible .nes file
; structure that, when assembled and linked, should spit out the binary image of
; a valid (albeit useless) .nes file.
; For the iNES file format, see: http://wiki.nesdev.com/w/index.php/INES

; =============================== iNES HEADER ==========================================

; First we create the iNES header, which we will assume can be said to start at $0000:
.org $0000

; ...and the following iNES header defines a .nes file which is expected to have the following
; binary layout:
;	1.	0x0000-0x000F:	Header (16 bytes).
;	2.	0x0010-0x400F:	PRG ROM (one PRG chunk; 16KiB).
;	3.	0x4010-0x600F:	CHR ROM (one CHR chunk; 8KiB).
; In total: 24,592 bytes. This is, typically, the smallest size a .nes file should be,
; even though a minimal program will use only a small portion of that available space.
; It is also possible to have ZERO chunks of CHR ROM, in which case the file would shrink
; by 8KiB (to 16,400 bytes in this case). That condition indicates CHR RAM is in use.

.byt "NES",$1A			; Header magic.
.byt 1 					; Specify that we have only 1 x PRG ROM chunk (16KiB).
.byt 1 					; ...and only 1 x CHR ROM chunk (8KiB).
.byt %00000000			; 'Flags 6' bits:
						;	{3,0}:
						;		00 = vertical arrangement with horizontal mirroring
						;		01 = horizontal arrangement with vertical mirroring
						;		1x = four-screen VRAM
						;	1:	1 = SRAM, if present, is battery backed-up. This SRAM (8KiB)
						;			would be located at $6000-$7FFF in the CPU's address space.
						;	2:	1 = A 512-byte 'trainer' immediately follows the iNES header,
						;			and would be mapped to $7000-$71FF.
						;	{7-4}: Lower nibble of the mapper number.
.byt %00000000			; 'Flags 7' bits:
						;	0:	1 = VS Unisystem (coin-slot-based machines).
						;	1:	1 = PlayChoice-10 (8KiB of Hint Screen data follows the CHR ROM).
						;	{3,2}:
						;		10 = Flags 8-15 are in NES 2.0 format.
						;	{7-4}: Upper nibble of the mapper number.
.byt 0 					; We have 0 x 8KiB chunks of PRG RAM, though apparently this actually
						; infers that we have 1 x 8KiB chunk, for compatibility reasons that I
						; don't fully understand but probably has something to do with a fallback
						; assumption that any given simple cartridge may or may not have had RAM??
						; See http://wiki.nesdev.com/w/index.php/PRG_RAM_circuit for more info.
.byt %00000000 			; 'Flags 9' bits:
						; 	0:	0 = NTSC; 1 = PAL. Actually this is mostly ignored.
						;	{7-1}:	Reserved, set to 0.
.byt %00000000			; 'Flags 10' bits:
						; 	{1,0}: TV system:
						;		00 = NTSC
						;		01 = dual compatible
						;		10 = PAL
						;		11 = dual compatible
						;	{3,2}: Unused.
						;	4:	0 = SRAM in $6000-$7FFF is present.
						;		1 = SRAM is absent.
						;	5:	0 = Board has no bus conflicts.
						;		1 = Board has bus conflicts, so adjust emulation to suit.
						; 		For more info, see: http://wiki.nesdev.com/w/index.php/Bus_conflict
.res (16-*), $00 		; Pad the rest of the header out to 16, with $00 as the filler.

; So in summary, the settings above define:
; 	* This is iNES 1 format.
;	* PRG ROM is one chunk; 16KiB.
;	* CHR ROM is one chunk; 8KiB.
;	* Use vertical arrangement of the VRAM, with horizontal mirroring.
;	* We're using mapper 000 (basic NROM).
;	* The iNES-implied 8KiB of RAM is assumed to be present at $6000-$7FFF on the bus.
;	* This is an NTSC cart.
;	* There are no bus conflicts.

; Note that, so far, all of this data is specific to the iNES format, and none of it is
; actual binary data that would appear in a real equivalent NES cartridge, though some of
; it DOES (sort of) describe the electronics in the cart.

; =============================== PRG ROM ==========================================

; PRG ROM size (defined above) is 16KiB, mapped to $C000-$FFFF.
.org $C000

	;;;;;;;;;;;;;;
	;; MAIN PRG CODE GOES HERE
	;;;;;;;;;;;;;;


; Pad out the PRG ROM to $FFFF.
.res ($10000-*), $00

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

; Pattern Table 0:
.org $0000

	;;;;;;;;;;;;;;
	;; PATTERN TABLE 0 DATA GOES HERE
	;;;;;;;;;;;;;;

; Pad out to 4KiB:
.res ($1000-*), $00

; Pattern Table 1:
	;;;;;;;;;;;;;;
	;; PATTERN TABLE 0 DATA GOES HERE
	;;;;;;;;;;;;;;

; Pad out to 8KiB:
.res ($2000-*), $00
