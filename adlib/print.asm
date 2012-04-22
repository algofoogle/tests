;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;	Output DX as a 16-bit hex string.
;;;;;;	See also: PUTHEX
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


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

