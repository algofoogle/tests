CC = xtensa-lx106-elf-gcc
CFLAGS = -I. -mlongcalls
# Add -lc for libc, including memchr(), per: https://www.bountysource.com/issues/38624771-undefined-reference-to-memchr
#LDLIBS = -nostdlib -Wl,--start-group -lmain -lnet80211 -lwpa -llwip -lpp -lphy -Wl,--end-group -lgcc
LDLIBS = -nostdlib -Wl,--start-group -lmain -lnet80211 -lwpa -llwip -lpp -lphy -lc -Wl,--end-group -lgcc
LDFLAGS = -Teagle.app.v6.ld

#NOTE: This will also build blinky_pwm-0x10000.bin:
blinky_pwm-0x00000.bin: blinky_pwm
	esptool.py elf2image $^

blinky_pwm: blinky_pwm.o

blinky_pwm.o: blinky_pwm.c

flash: blinky_pwm-0x00000.bin
	esptool.py --baud 230400 write_flash 0 blinky_pwm-0x00000.bin 0x10000 blinky_pwm-0x10000.bin

# This is here because it's the original, but my bin files are at different addresses:
flash-old: blinky_pwm-0x00000.bin
	esptool.py write_flash 0 blinky_pwm-0x00000.bin 0x40000 blinky_pwm-0x40000.bin

clean:
	rm -f blinky_pwm blinky_pwm.o blinky_pwm-0x00000.bin blinky_pwm-0x10000.bin blinky_pwm-0x40000.bin

