;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;	IRQ8-based delay() function.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Enable use of the "delay" routine.
%macro DELAY_INIT 0
	call irq8_install_isr
	; Set the interrupt rate as fast as the RTC can go (8192Hz):
	RTCRATE 3
	IRQ8 ON
%endmacro

; Undo DELAY_INIT:
%macro DELAY_CLEANUP 0
	IRQ8 OFF
	; Set the interrupt rate to the default 1024Hz:
	RTCRATE 6
	call irq8_remove_isr
%endmacro

; Set the RTC frequency divider to set the interrupt rate:
; f = 32768 >> (rate-1) =>
;   1 & 2 = not allowed (unstable)
;   3 = 8192Hz
;   4 = 4096Hz
;   5 = 2048Hz
;   6 = 1024Hz (default)
;   7 = 512Hz
; ...
;   15 = 2Hz
%macro RTCRATE 1
	cli
	RTCGET A
	and al, 0xF0 ; clear lower 4 bits.
	or al, 3 ; Select rate-3 (8192Hz) in lower 4 bits:
	RTCSET A
	sti
%endmacro

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

; Turn IRQ8 on or off:
;   IRQ8 ON
; or:
;   IRQ8 OFF
; Destroys AH.
%macro IRQ8 1
	mov ah, %1
	call irq8_control
%endmacro

; Wait for a given number of cycles, at 8192Hz.
; Thus, the delay is (%1/8192) seconds.
%macro DELAY 1
	push ax
	mov ax, %1
	call delay
	pop ax
%endmacro

; Wait for (approx) a given number of milliseconds:
%macro DELAY_MS 1
	push ax
	mov ax, ((%1 * 8192) + 500) / 1000
	call delay
	pop ax
%endmacro


; Restore the old IRQ 8 ISR:
irq8_remove_isr:
	PUSHAF
	%ifdef DEBUG
		WRITE "Restoring IRQ 8 ISR: "
	%endif
	cli
	xor ax, ax
	mov es, ax ; ES = 0
	mov di, (0x70 * 4)
	mov si, irq8_old_vector
	movsw ; IP
	movsw ; CS
	sti
	%ifdef DEBUG
		WRITELN "Done"
	%endif
	POPAF
	ret


irq8_install_isr:
	; ---- Insert our own IRQ 8 ISR: ----
	PUSHAF
	%ifdef DEBUG
		WRITE "Installing IRQ 8 ISR: "
	%endif
	; Disable interrupts while we do this.
	cli
	; NOTE: May be important to disable NMI at times. See: http://wiki.osdev.org/RTC#Avoiding_the_NMI
	; Get the old ISR for IRQ 8 (timer), which lives at INT 0x70 vector:
	xor bx, bx ;
	mov ds, bx ; DS = 0
	push cs
	pop es ; ES = CS
	mov si, (0x70 * 4)
	push si
	mov di, irq8_old_vector
	; Copy old ISR vector:
	movsw ; IP
	movsw ; CS
	; Now insert our new ISR:
	mov es, bx ; ES = 0
	pop di ; DI = (0x70 * 4)
	mov ax, irq8_isr
	stosw ; IP.
	mov ax, cs
	stosw ; CS.
	; Done installing ISR, so re-enable interrupts.
	sti
	%ifdef DEBUG
		; ---- Display ISR info: ----
		mov ds, ax ; DS = CS.
		; old:
		WRITE "old="
		PUTHEX [irq8_old_cs]
		PUTC ':'
		PUTHEX [irq8_old_ip]
		; new:
		WRITE " - new="
		PUTHEX CS
		PUTC ':'
		PUTHEX irq8_isr
		PUTNL
	%endif
	POPAF
	ret

; This will get loaded with the old IRQ 8 ISR vector:
irq8_old_vector:
irq8_old_ip:
	dw 0
irq8_old_cs:
	dw 0

; Enable IRQ8 if AH non-zero. Otherwise, disable.
irq8_control:
	PUSHAF
	cli
	RTCGET B
	; Turn on bit 6:
	or al, bit(6)
	or ah, ah
	jnz .done
	; Oh, AH was 0, turn OFF bit 6:
	xor al, bit(6)
.done:
	RTCSET B
	sti
	POPAF
	ret

; This is our replacement ISR for IRQ 8:
irq8_isr:
	PUSHAF
	; Decriment delay counter, if not already zero:
	mov cx, [cs:delay_counter]
	jcxz .done
	dec word [cs:delay_counter]
.done:
	; Read RTC register C, only so we will keep getting interrupts:
	RTCGET C
	POPAF
	; Call the original ISR:
	jmp far [cs:irq8_old_vector]

; This will decriment at 1024Hz, until 0:
delay_counter:
	dw 0


; Pause for *roughly* AX milliseconds.
delay:
	PUSHAF
	; Set the delay count (i.e. no. of 1/1024-second cycles to wait).
	; We have incremented AX by 1, just to be sure we do not miss
	; an early firing of IRQ 8 and return too soon.
	inc ax
	; Atomic write:
	cli
	mov [cs:delay_counter], ax
	sti
	; Now, we assume IRQ 8 is already firing and irq8_isr is already 
	; handling it, so we just loop until the delay counter reaches 0:
.wait:
	mov ax, [cs:delay_counter]
	or ax, ax
	jnz .wait
	; It APPEARS we hit zero. Do atomic read to check.
	cli
	mov ax, [cs:delay_counter]
	sti
	or ax, ax
	jnz .wait
	POPAF
	ret
