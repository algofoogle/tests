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
