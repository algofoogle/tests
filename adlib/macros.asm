%define bit(n) (1<<n)
%define ON 0xFF
%define OFF 0x00
%macro PUSHAF 0
	pushf
	pusha
%endmacro
%macro POPAF 0
	popa
	popf
%endmacro

; String stuff for use with int 0x21/09:
%define CRLF 13, 10
%define CRLFD CRLF, '$'

; MSDOS exit-with-errorlevel:
%macro EXIT 1
	mov ax, %1
	mov ah, 0x4c
	int 0x21
%endmacro

%macro STRING_TABLE 1-*
	; Define the string pointers:
	%assign index 0
	%rep %0
		%assign index (index+1)
		dw .str_%+ index
		%rotate 1
	%endrep
	; Define the strings, with labels for pointers:
	%assign index 0
	%rep %0
		%assign index (index+1)
		.str_%+ index:
		db %1
		%rotate 1
	%endrep
%endmacro
