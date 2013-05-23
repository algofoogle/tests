;; Here we have the roughest example of a raw .nes (INES) file, with
;; addresses set manually. Later we'll supersede this with .segments and a linker config file.
;; For more information on the NES memory map, see: http://wiki.nesdev.com/w/index.php/CPU_memory_map
;
;; INES header...
;; For more info, see: http://wiki.nesdev.com/w/index.php/INES
;.byt "NES", $1A		; Magic signature: "NES" followed by DOS ASCII 'EOF' character 0x1A.
;.byt 1 				; No. of 16KiB PRG ROM (main program code) chunks, starting at $C000 when using mapper 000 (NROM).
;.byt 1 				; No. of 8KiB CHR ROM (pattern data) chunks, which follows immediately after the PRG ROM(s).
;.byt $00 			; Mirroring type and mapper number lower nibble.
;.byt $00 			; Mapper number upper nibble.
;
;; Set the relative address for the following code to start at $C000, so that jumps and such work,
;; despite this code being relocated to a section of memory that is different from where it is found
;; in the .nes file:
;.org $C000
;	jmp test
;	nop
;	nop
;	nop
;
;test:
;	jmp test
;
;;reset:
;;  lda #$01	; square 1
;;  sta $4015
;;  lda #$08	; period low
;;  sta $4002
;;  lda #$02	; period high
;;  sta $4003
;;  lda #$bf	; volume
;;  sta $4000
;;forever:
;;  jmp forever
;;  

.org $100
.byte "Hi"

