; AdLib programming info: http://www.shipbrook.net/jeff/sb.html

%define ADLIB_ADDR 0x388
%define ADLIB_DATA 0x389

ym_wse	equ 1 	; Test LSI / Waveform Select Enable.
ym_t1	equ 2 	; Timer 1 Count.
ym_t2	equ 3 	; Timer 2 Count.
ym_ctl	equ 4 	; Timer control flags.
ym_ksp	equ 8	; Composite sine mode / NOTE-SEL (keyboard split).


; %1 = register, %2 = data
%macro ADLIB_OUT 2
	; Select the register:
	mov al, %1
	mov dx, ADLIB_ADDR
	out dx, al
	; MUST wait at least 3.3us, but we'll wait about 122us:
	DELAY 1
	; Output the data:
	mov al, %2
	mov dx, ADLIB_DATA
	out dx, al
	; Must wait at least 23us before sending more data.
	; Here we just force -- again -- about a 122us wait:
	DELAY 1
%endmacro

; Read the status of the AdLib card:
; bit 7 = any timer expired?
; bit 6 = timer 1 expired?
; bit 5 = timer 2 expired?
%macro ADLIB_STATUS 0-1
	mov dx, ADLIB_ADDR
	in al, dx
	%if %0 == 1
		mov %1, al
	%endif
%endmacro

; This should return BX = 0xC000 if an AdLib device exists.
adlib_detect:
	push ax
	push dx
	; Reset timers:
	ADLIB_OUT ym_ctl, 0110_0000b ; Mask T1 (bit 6) and T2 (bit 5).
	; Enable/reset interrupts:
	ADLIB_OUT ym_ctl, 1000_0000b ; bit 7 = reset flags for all timers.
	; NOTE: When bit 7 of ym_ctl is set, all other bits are ignored.
	; Get status into BL:
	ADLIB_STATUS bl
	; Give T1 a value that will roll over quickly:
	ADLIB_OUT ym_t1, 0xff
	; Start T1:
	ADLIB_OUT ym_ctl, 0010_0001b ; Enable T1.
	; Wait at least 80us -- will actually be a lot more:
	DELAY 2
	; Get status, into BH this time:
	ADLIB_STATUS bh
	; Reset timers and enable interrupts again:
	ADLIB_OUT ym_ctl, 0110_0000b
	ADLIB_OUT ym_ctl, 1000_0000b
	and bx, 0xe0e0 ; Extract timer status bits.
	; At this point, BX = 0xC000 means T1 went from a reset
	; state to an expired (i.e. rollover) state.
	pop dx
	pop ax
	ret
