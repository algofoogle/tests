# Command used for assembling AVR assembly language files (*.asm):
ASM=avr-as

# Command for linking object files (*.o) to ELF binaries:
LINKER=avr-ld

# Command used for extracting binary data from ELF (*.elf) files:
OBJCOPY=avr-objcopy

# Device used for burning:
ISP=usbasp

# Device we're burning to (ATtiny13A):
DEVICE=t13

# AVRDUDE is used to interace with USBasp to burn to ATtiny13A:
BURN=avrdude -c $(ISP) -p $(DEVICE)

# Command for deleting stuff (e.g. during 'clean'):
ifndef HOME
  # HOME var not set... Let's assume Windows
  RM=del
else
  # Got a home directory, so let's assume Unix:
  RM=rm -f
endif

# Default build: Produce a binary file, and an Intel HEX file we can burn.
all:        test.bin test.hex

rebuild:	clean all

# Do clean, build test.hex, and burn it.
rewrite:	clean test.hex burn

# Burn test.hex to an ATtiny13 using avrdude:
burn:       test.hex
	$(BURN) -U flash:w:test.hex:i

# Bring up the AVRDUDE terminal:
burnterm:
	$(BURN) -t

burntermf:
	$(BURN) -t -F

# Generate a HEX file that a burner can use:
test.hex:	test.elf
	$(OBJCOPY) --output-target=ihex test.elf test.hex

# Generate a compiled binary from the compiled ELF:
test.bin:   test.elf
	$(OBJCOPY) --output-target=binary test.elf test.bin

# Generate a compiled ELF from the Object file:
test.elf:   test.o
	$(LINKER) test.o -o test.elf

# Compile the assembly source to an object file:
test.o:
	$(ASM) test.asm -mmcu=attiny13a -o test.o

# Delete any of our (possible) output files:
clean:
	$(RM) test.bin test.hex test.elf test.o

