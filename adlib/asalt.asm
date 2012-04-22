org 0x100
	jmp start

%define DEBUG

; I've placed these here, because at the moment this will compile
; to a .com file and we can't have anything preceding the entrypoint.
%include 'macros.asm'
%include 'delay.asm'
%include 'print.asm'


org 0x100
start:
	WRITELN "Anton",39,"s Simple AdLib Test"
	DELAY_INIT

	; Test delays from ~250ms to ~2sec:
	mov cx, 4
	mov si, delay_strings
	mov bx, 256 ; 256/1024 === 0.25sec
.next_delay:
	WRITE "Testing delay: "
	lodsw
	mov dx, ax
	mov ah, 9
	int 0x21
	mov ax, bx
	call delay
	shl bx, 1
	WRITELN " - Done"
	loop .next_delay

	DELAY_CLEANUP
	WRITELN "All done. Bye!"
stop:
	EXIT 0


delay_strings:
	STRING_TABLE "250ms$", "500ms$", "1sec$", "2sec$"


