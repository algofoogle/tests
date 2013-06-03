
PPU_CTRL 		= $2000
PPU_MASK		= $2001
;PPU_STATUS		= $2002	; Defined in nes.inc
PPU_OAM_ADDR	= $2003	; OAM = "Object Attribute Memory", for sprites.
PPU_OAM_DATA	= $2004
; NOTE: Use OAM_DMA instead of OAM_DATA. That is, instead of directly latching
; each byte into the PPU's RAM, we 
PPU_SCROLL		= $2005
PPU_ADDR		= $2006
PPU_DATA		= $2007

APU_DMC_CTRL	= $4010
APU_CHAN_CTRL	= $4015
APU_FRAME		= $4017

; NOTE: I've put this outside of the PPU & APU, because it is a feature
; of the APU that is primarily of use to the PPU.
OAM_DMA			= $4014
; OAM local RAM copy goes from $0200-$02FF:
OAM_RAM			= $0200

; PPU_CTRL bit flags:
; NOTE: Many of these are expressed in binary,
; to highlight which bi(s) they pertain to:
BG_0			= %00000	; Use background pattern table 0 ($0000).
SPR_0			= %0000		; Use sprite pattern table 0.
VRAM_RIGHT		= %000		; Increment nametable address rightwards, after a write.
NT_0			= %00		; Use nametable 0 ($2000).
NT_1			= %01		; Use nametable 1 ($2400).
NT_2			= %10		; Use nametable 2 ($2800).
NT_3			= %11		; Use nametable 3 ($2C00).
VRAM_DOWN		= %100		; Increment nametable address downwards, after a write.
SPR_1			= %1000		; Use sprite pattern table 1.
BG_1			= %10000	; Use background pattern table 1 ($1000).
SPR_8x16		= %100000	; Use 8x16 sprites, instead of 8x8.
VBLANK_NMI 		= %10000000	; Generate VBLANK NMIs?

; PPU_MASK bit flags:
SPR_OFF			= %00000	; Hide sprites.
BG_OFF			= %0000		; Hide background.
HIDE_SPR_LHS	= %000		; Prevent displaying sprites in left-most 8 pixels of screen.
HIDE_BG_LHS		= %00		; Hide left-most 8 pixels of the background.
COLOR_NORMAL	= %0
COLOR_GRAYSCALE	= %1
SHOW_BG_LHS		= %10		; Show left-most 8 pixels of BG.
SHOW_SPR_LHS	= %100		; Show sprites in left-most 8 pixels of screen.
BG_ON			= %1000		; Show background.
SPR_ON			= %10000	; Show sprites.



; Load a given 16-bit address into the PPU_ADDR register.
.macro ppu_addr		Addr
	ldx #>Addr		; High byte first.
	stx PPU_ADDR
	ldx #<Addr		; Then low byte.
	stx PPU_ADDR
.endmacro

; Seek to a given X,Y address in the nametable.
; If the 3nd parameter is given, it is 0, 1, 2, or 3 to specify which nametable
; (i.e. which base address). Otherwise, 0 ($2000) is assumed.
.macro ppu_xy	cx, cy, nt
	.ifblank nt
		ppu_addr ($2000+(cy*32)+cx)
	.else
		ppu_addr ($2000+(nt*$400)+(cy*32)+cx)
	.endif
.endmacro

.macro	pal	bb, uu, vv, ww
	.ifnblank ww
		.byt bb, uu, vv, ww
	.else
		.byt $00, bb, uu, vv
	.endif
.endmacro

