CC = xtensa-lx106-elf-gcc
CFLAGS = -I. -mlongcalls
# Add -lc for libc, including memchr(), per: https://www.bountysource.com/issues/38624771-undefined-reference-to-memchr
#LDLIBS = -nostdlib -Wl,--start-group -lmain -lnet80211 -lwpa -llwip -lpp -lphy -Wl,--end-group -lgcc
LDLIBS = -nostdlib -Wl,--start-group -lmain -lnet80211 -lwpa -llwip -lpp -lphy -lc -Wl,--end-group -lgcc
LDFLAGS = -Teagle.app.v6.ld

#NOTE: This will also build blinky-0x10000.bin:
blinky-0x00000.bin: blinky
	esptool.py elf2image $^

blinky: blinky.o

blinky.o: blinky.c

flash: blinky-0x00000.bin
	esptool.py --baud 57600 write_flash 0 blinky-0x00000.bin 0x10000 blinky-0x10000.bin

# This is here because it's the original, but my bin files are at different addresses:
flash-old: blinky-0x00000.bin
	esptool.py write_flash 0 blinky-0x00000.bin 0x40000 blinky-0x40000.bin

clean:
	rm -f blinky blinky.o blinky-0x00000.bin blinky-0x10000.bin blinky-0x40000.bin

