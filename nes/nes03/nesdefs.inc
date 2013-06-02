
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

; Load a given 16-bit address into the PPU_ADDR register.
.macro ppu_addr		Addr
	ldx #>Addr		; High byte first.
	stx PPU_ADDR
	ldx #<Addr		; Then low byte.
	stx PPU_ADDR
.endmacro

.macro	pal	bb, uu, vv, ww
	.ifnblank ww
		.byt bb, uu, vv, ww
	.else
		.byt $00, bb, uu, vv
	.endif
.endmacro