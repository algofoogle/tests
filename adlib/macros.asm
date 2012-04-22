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

; Read a given RTC register into AL:
%macro RTCGET 1
	; Select register:
	mov al, 0x%1
	out 0x70, al
	in al, 0x71
%endmacro

; Write value in AL into a given RTC register.
; Destroys AH.
%macro RTCSET 1
	; Select register:
	mov ah, al
	mov al, 0x%1
	out 0x70, al
	mov al, ah
	out 0x71, al
%endmacro

; Turn IRQ8 on or off.
; Destroys AH.
%macro IRQ8 1
	mov ah, %1
	call irq8_control
%endmacro

%macro EXIT 1
	mov ax, %1
	mov ah, 0x4c
	int 0x21
%endmacro

; Enable use of the "delay" routine.
%macro DELAY_INIT 0
	call irq8_install_isr
	IRQ8 ON
%endmacro

; Undo DELAY_INIT:
%macro DELAY_CLEANUP 0
	IRQ8 OFF
	call irq8_remove_isr
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
