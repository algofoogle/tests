; Output a string, like this: WRITE "foo", ...
%macro WRITE 1+
	push ds
	push cs ;
	pop ds  ; DS = CS.
	mov ah, 9
	mov dx, %%msg
	int 0x21
	jmp %%skip
%%msg:
	db %1, '$'
%%skip:
	pop ds
%endmacro

; Output a string, with a newline at the end.
%macro WRITELN 1+
	WRITE %1, CRLF
%endmacro

; Output a single character.
%macro PUTC 1
	mov ah, 2
	mov dl, %1
	int 0x21
%endmacro

; Display DX as a hex string:
%macro PUTHEX 1
	mov dx, %1
	call print_hex
%endmacro

; Print a newline:
%define PUTNL WRITELN ''



; Output DX as a 16-bit hex string.
; See also, the PUTHEX macro: it wraps this.
print_hex:
	PUSHAF
	mov ah, 2 ; This tells int 0x21 to write a char.
	mov cx, 4
.next:
	rol dx, 4
	mov al, 0x0f
	push dx
	and dl, al
	add dl, 0x30
	cmp dl, 0x3a
	jb .under
	; Add more to get A-F:
	add dl, 7
.under:
	int 0x21
	pop dx
	loop .next
	POPAF
	ret

