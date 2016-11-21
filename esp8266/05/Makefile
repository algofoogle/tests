MAIN = demo
BAUD = 1500000 # 230400
CC = xtensa-lx106-elf-gcc
CFLAGS = -I. -mlongcalls
# Add -lc for libc, including memchr(), per: https://www.bountysource.com/issues/38624771-undefined-reference-to-memchr
#LDLIBS = -nostdlib -Wl,--start-group -lmain -lnet80211 -lwpa -llwip -lpp -lphy -Wl,--end-group -lgcc
LDLIBS = -nostdlib -Wl,--start-group -lmain -lnet80211 -lwpa -llwip -lpp -lphy -lc -Wl,--end-group -lgcc
LDFLAGS = -Teagle.app.v6.ld

#NOTE: This will also build blinky_pwm-0x10000.bin:
$(MAIN)-0x00000.bin: $(MAIN)
	esptool.py elf2image $^

$(MAIN): $(MAIN).o

$(MAIN).o: $(MAIN).c

flash: $(MAIN)-0x00000.bin
	esptool.py --baud $(BAUD) write_flash 0 $(MAIN)-0x00000.bin 0x10000 $(MAIN)-0x10000.bin

clean:
	rm -f $(MAIN) $(MAIN).o $(MAIN)-0x00000.bin $(MAIN)-0x10000.bin $(MAIN)-0x40000.bin

