org 0x100
	jmp start

%define DEBUG

; I've placed these here, because at the moment this will compile
; to a .com file and we can't have anything preceding the entrypoint.
%include 'macros.asm'
%include 'print.asm'
%include 'delay.asm'
%include 'adlib.asm'

org 0x100
start:
	WRITELN "Anton",39,"s Simple AdLib Test"
	call init

	; Test a 1-sec delay:
	WRITE "Testing 1sec delay: "
	DELAY_MS 1000
	WRITELN "Done"

	; Try to detect AdLib card.
	WRITE "Testing AdLib card: "
	call adlib_detect
	; adlib_detect will return BX = 0xC000 if the card is present.
	cmp bx, 0xC000
	jz .found_adlib
	WRITE "NOT FOUND: 0x"
	PUTHEX bx
	PUTNL
	jmp .done
.found_adlib:
	WRITELN "OK"

	; Reset AdLib.
	call adlib_reset

	; Simple AdLib noise test.
	WRITELN "Playing a sample note..."
	; Set channel 1's feedback to 2:
	ADLIB_FB 1, 2

	; Define the channels (i.e. "instruments"):

	; Channel 0 - a warm resonant sound:
	;            Ch Op Mx Lv   A  D   S  R
	ADLIB_CHANOP 0, 0, 0, 48, 10, 3,  5, 6
	ADLIB_CHANOP 0, 1, 1, 50,  4, 0, 12, 4

	; Channel 1 - a short bass pluck:
	;            Ch Op Mx Lv   A  D   S  R
	ADLIB_CHANOP 1, 0, 0, 55,  7, 5,  8, 3
	ADLIB_CHANOP 1, 1, 0, 63, 13, 5,  5, 8

	; 
	%assign i 0x40
	%rep 1
		%assign i i+0x15
		ADLIB_NOTE i, 4, ON, 1
		ADLIB_NOTE i, 4, ON, 0
		%rep 0x1A
			%assign i i+1
			DELAY 20
			ADLIB_NOTE i, 4, ON, 1
			ADLIB_NOTE i, 4, ON, 0
		%endrep
		DELAY_MS 250
	%endrep

	DELAY_MS 2000
	WRITELN "Note off => Release..."
	; Key-off:
	ADLIB_NOTE i, 4, OFF, 0
	DELAY_MS 50
	ADLIB_NOTE i, 4, OFF, 1

	DELAY_MS 2000
	WRITELN "Shutting down..."
	; Reset Adlib (cleanup)
	call adlib_reset

.done:
	call cleanup
	WRITELN "All done. Bye!"
stop:
	EXIT 0


init:
	DELAY_INIT
	ret

cleanup:
	DELAY_CLEANUP
	ret
