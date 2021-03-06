; This file does nothing more than toy with various ca65 control commands
; (see: http://www.cc65.org/doc/ca65-11.html#control-commands),
; and prove that we can produce a binary (i.e. output/test.prg) with highly
; predictable content if we want to.
; 
; Compile with:
;   ./bb
; Which is roughly equivalent to:
;   # Compile to object file:
;   ca65 test.s -o test output/test.o
;   # Link to bare binary:
;   ld65 output/test.o -o output/test.prg -m output/map.txt -t none
; View contents with:
;   hexdump -C output/test.prg

; By default, we start off with an 'address' of $0200, at the very start of the file.
; This is because, by default, we're in the system-defined 'CODE' segment which,
; by default, must be set to start at the $0200 address. This was confirmed by 
; examining the output/map.txt file generated by ld65, as described above.
; Note that, by putting "-l" into the ca65 line, you can generate a listing
; file which shows exactly what bytes were generated (and at what relative addresses)
; by the assembly process. This reveals, for instance that the addresses (up
; until the first ".org" command I have below) are 'relocatable' (i.e. they have
; an 'r' at the end of them in the listing), so that the final address of the CODE
; segment is not necessarily set in stone until the linking stage.

; The very first byte of the file will be an exclamation point (ASCII 0x21):
.byt $21													; 21
; Now our 'address' is at $0201

; Now store a string (again, followed by an exclamation point):
.byt "Hello, World", $21									; 48 65 6c 6c 6f 2c 20 57 6f 72 6c 64 21
; That was 13 bytes, putting our address now at $020E. Let's create a label
; that will effectively 'be' that address...

first_label:			; Now equiv to $020E

; Store a word, in this case $89AB, which will turn into two bytes:
; $AB and $89 (i.e. little-endian):
.word $89AB													; AB 89
; Address: $0210

; Store a word which is equal to the address of first_label:
.word first_label											; 0E 02
; Address: $0212

; Store a word which is the CURRENT address:
.word (*)													; 12 02
; Address: $0214

; Store a word which is an expression derrived from the current address:
.word (* - first_label + 20)	; $0214-$020E+$0014=$001A	; 1A 00
; Address: $0216

; NOW let's mess with our "origin" (i.e. address) a bit, first by putting it
; back to $0000:
.org $0000
; Address: $0000

; ...such that storing a word containing the current address will now get $0000:
.word *														; 00 00
; Address: $0002

; Then advance to $CDEF:
.org $CDEF
; Address: $CDEF

; This causes the 'e' character in strings ($65) to be mapped to 'E' instead ($45)
.charmap 'e', $45

; ...then put a string (this time with a CR & LF, which are evidently NOT supported with "\r\n"):
.byt 'H', "ello", $0D, $0A										; 48 45 6c 6c 6f 0D 0A
; Address: $CDF6

; Now capture that address:
second_label:

; Then offset again...
.org $1000
; Address: $1000

; ...then store the address before the offset:
.word second_label											; F6 CD
; Address: $1002

; ...and finally store the CURRENT address again, but this time as a 'double-byte' (which is big-endian):
.dbyt *														; 10 02
; Address: $1004

third_label:
; We can confirm that we definitely have reached that address now, by using an .assert:
.assert * = $1004, error, "third_label is NOT at $1004"

; Now store a double-word (little-endian):
.dword $12345678											; 78 56 34 12
; Address: $1008

; Now 'reserve' (fill) 10 bytes with $EE:
.res 10, $EE 												; EE EE EE EE EE EE EE EE EE EE
; Address: $1012
