; AdLib programming info: http://www.shipbrook.net/jeff/sb.html

%define ADLIB_ADDR 0x388
%define ADLIB_DATA 0x389
; This calculates the register address for a given channel & operator, on a base.
; chan=[0,8] ; op=[0,1]
%define ym_reg(base, chan, op)	(base + ((chan/3)*5 + (op*3) + chan))

ym_wse	equ 1 		; Test LSI / Waveform Select Enable.
ym_t1	equ 2 		; Timer 1 Count.
ym_t2	equ 3 		; Timer 2 Count.
ym_ctl	equ 4 		; Timer control flags.
ym_ksp	equ 8		; Composite sine mode / NOTE-SEL (keyboard split).
ym_fx	equ 0xBD	; Tremolo & Vibrato Depth / Percussion keys.
; Use ym_reg with these:
ym_mod	equ 0x20	; Base for: Tremolo / Vibrato / Sustain / KSR / FM factor.
ym_lev	equ 0x40	; Base for: Key Scale Level / Output Level attenuation.
ym_ad	equ 0x60	; Base for: Attack / Decay rates.
ym_sr	equ 0x80	; Base for: Sustain / Release rates.
ym_wave	equ 0xE0 	; Base for: Waveform Select.
; Just add channel number to these:
ym_lof	equ 0xA0	; Base for: F-Number LSB.
ym_hif	equ 0xB0	; Base for: F-Number MSB / Octave / Key-On.
ym_fb	equ 0xC0 	; Base for: Feedback / Algorithm.

; Set Feedback and optionally non-modulated synthesis:
; %1 = channel
; %2 = feedback [0,7]
; %3(optional) = ON for modulated output (default) or OFF for dual-sine.
%macro ADLIB_FB 2-3
	%if %0 == 3
		ADLIB_WR fb+%1, (%2<<1) | ((%3 & 1)^1)
	%else
		ADLIB_WR fb+%1, (%2<<1)
	%endif
%endmacro

; Simple AdLib register write:
; %1 = register, %2 = data
%macro ADLIB_WR 2
	push bx
	mov bl, ym_%+ %1
	mov bh, %2
	call adlib_write
	pop bx
%endmacro

; Write to a given channel's operator:
; %1 = data (byte)
; %2 = channel (0-8)
; %3 = operator (0-1)
; %4 = base (t1, ctl, ...)
%macro ADLIB_OP 4
	push bx
	mov bl, ym_reg(ym_%+ %4, %2, %3)
	mov bh, %1
	call adlib_write
	pop bx
%endmacro

; Read the status of the AdLib card:
; bit 7 = any timer expired?
; bit 6 = timer 1 expired?
; bit 5 = timer 2 expired?
%macro ADLIB_STATUS 0
	push dx
	mov dx, ADLIB_ADDR
	in al, dx
	pop dx
%endmacro

; %1 = channel
; %2 = operator
; %3 = mul: [0,15]
; %4 = Level: [0,63]
; %5 = Attack
; %6 = Decay
; %7 = Sustain
; %8 = Release
%macro ADLIB_CHANOP 8
	ADLIB_OP (%3 & 0x0F), %1, %2, mod
	ADLIB_OP (0x3F - %4), %1, %2, lev
	ADLIB_OP ((%5 << 4) | %6), %1, %2, ad
	ADLIB_OP ((%7 << 4) | %8), %1, %2, sr
%endmacro

; %1 = F-number
; %2 = Octave
; %3 = ON or OFF
; %4 = Channel
%macro ADLIB_NOTE 4
	ADLIB_WR lof + %4, (%1 & 0xFF)
	%if %3 == ON
		ADLIB_WR hif + %4, ((%1 >> 8) | (%2 << 2) | 0010_0000b)
	%else
		ADLIB_WR hif + %4, ((%1 >> 8) | (%2 << 2) | 0)
	%endif
%endmacro



; Register goes in BL, Data goes in BH.
adlib_write:
	PUSHAF
	%ifdef DEBUG
		; Display the register/data pair.
		mov dx, bx
		call print_hex
		PUSHAF
		PUTNL
		POPAF
	%endif
	; Select the register:
	mov dx, ADLIB_ADDR
	mov al, bl
	out dx, al
	; Pause for >= 3.3us.
	mov ax, 1
	call delay
	; Output the data;
	inc dx
	mov al, bh
	out dx, al
	; Pause for >= 23us.
	mov ax, 1
	call delay
	POPAF
	ret


; This should return BX = 0xC000 if an AdLib device exists.
adlib_detect:
	push ax
	push dx
	; Reset timers:
	ADLIB_WR ctl, 0110_0000b ; Mask T1 (b6) and T2 (b5).
	; Reset IRQ:
	ADLIB_WR ctl, 1000_0000b ; b0-b6 ignored when b7==1
	; Get status into BL:
	ADLIB_STATUS
	mov bl, al
	; Give T1 a value that will roll over quickly:
	ADLIB_WR t1, 0xff
	; Start T1:
	ADLIB_WR ctl, 0010_0001b ; Unmask (b6) & start (b0) T1.
	; Wait at least 80us (this is actually >= 122us):
	DELAY 1
	; Get status, into BH this time:
	ADLIB_STATUS
	mov bh, al
	; Reset timers and enable interrupts again:
	ADLIB_WR ctl, 0110_0000b
	ADLIB_WR ctl, 1000_0000b
	and bx, 0xe0e0 ; Extract timer status bits.
	; At this point, BX = 0xC000 means T1 went from a reset
	; state to an expired (i.e. rollover) state.
	pop dx
	pop ax
	ret

; Reset AdLib state by setting all registers to 0.
adlib_reset:
	PUSHAF
	mov cx, 0xf5 ; There are 244 registers, but note they range 0x01-0xF5.
	xor bh, bh
.next:
	mov bl, 0xf6 ; 
	sub bl, cl   ; This makes BL count UP from 0x01.
	call adlib_write
	loop .next
	POPAF
	ret
