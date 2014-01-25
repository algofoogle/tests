# Command used for assembling AVR assembly language files (*.s):
ASM=avr-as

# Command for linking object files (*.o) to ELF binaries:
LINKER=avr-ld

# Command used for extracting binary data from ELF (*.elf) files:
OBJCOPY=avr-objcopy

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
	$(ASM) test.s -mmcu=attiny13a -o test.o

# Delete any of our (possible) output files:
clean:
	$(RM) test.bin test.hex test.elf test.o

