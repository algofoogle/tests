# ESP8266 tests

## `01` and `02` - NodeMCU tests

* `01` - A very simple NodeMCU Lua example that serves a web page that includes a
  GPIO switch. It's not overly stable due to how I've coded it and the memory
  constraints of NodeMCU.
* `02` - An improvement that serves a web page from a HTML file specifically, and
  offers four GPIO switches. This is a little more stable and extensible. It's
  based on code examples from a few other people.

### My NodeMCU board

The board I'm testing with is [eBay item #142121272679](http://www.ebay.com.au/itm/142121272679): ESP12E "V3", branded with <http://wemos.cc>, "LoLin", and "Ver 0.1". For more info, see: <http://frightanic.com/iot/comparison-of-esp8266-nodemcu-development-boards/>

Apparently, the specific board I have is mentioned here: <http://frightanic.com/iot/comparison-of-esp8266-nodemcu-development-boards/#v3>
...whose key difference from other boards is pins 2 and 3 (assuming pin 1 is the top-left)
which are GND (`G`) and USB +V (`VU`) respectively:

![NodeMCU V3 pin-out](esp8266-nodemcu-dev-kit-v3-pins.jpg?raw=true)!

The eBay listing states the following:

* NodeMcu ESP8266 V3 LUA CH340 WIFI Internet Development Board Module TB
* **Uses CH340G** instead of CP2102.
* Communication interface voltage: **3.3V.**
* Antenna type: Built-in PCB antenna is available.
* Wireless 802.11 b/g/n standard
* WiFi at 2.4GHz, **support WPA / WPA2** security mode
* Support STA/AP/STA + AP three operating modes
* Built-in TCP/IP protocol stack to support **multiple TCP Client connections (5 MAX)**
* D0 ~ D8, SD1 ~ SD3: used as GPIO, PWM, IIC, etc., **port driver capability 15mA**
* **AD0: 1 channel ADC**
* **Power input: 4.5V ~ 9V** (10VMAX), **USB-powered**
* Current: continuous transmission: **≈70mA (200mA MAX), Standby: < 200uA**
* Transfer rate: 110-460800bps
* Support UART / GPIO data communication interface
* Remote firmware upgrade (OTA)
* Support Smart Link Smart Networking
* Working temperature: -40 ℃ ~ + 125 ℃
* Drive Type: Dual high-power H-bridge driver
* ESP8266 has IO Pin
* Don't need to download resetting
* A great set of tools to develop ESP8266
* **Flash size: 4MByte**

### NodeMCU GPIO pins

See here: <https://nodemcu.readthedocs.io/en/master/en/modules/gpio/>

## `03` - `blinky` test modified from `esp-open-sdk`

This is a copy of the [`blinky` example](https://github.com/pfalcon/esp-open-sdk/tree/master/examples/blinky)
from [`esp-open-sdk`](https://github.com/pfalcon/esp-open-sdk). Note that,
as such, it requires the `esp-open-sdk`, but arguably makes for a much
more compact binary (with better memory usage) to run on an ESP8266 module.

In this case, I'm using an
[ESP-01 module](http://homecircuits.eu/blog/programming-esp01-esp8266/) to test.

I've modified the stock `blinky` example slightly,
based on some observed changes in the standard `make` process:

1.  The `c` library needs to be included in `LDLIBS` via the `-lc`
    parameter, in order to implement `memchr()`. NOTE: Apparently this
    can be avoided if the built-in ESP8266 version of that function
    can be linked, instead, but I can't be bothered with figuring that
    out for now: At the time of writing it requires a patch.
2.  With my installation of `esp-open-sdk` (and the specific
    "ESP8266 NONOS SDK" that it grabs), it builds the `blinky` ELF
    binary such that it yields `blinky-0x00000.bin` and
    **`blinky-0x10000.bin`** (instead of `blinky-0x40000.bin`)
    so, until I make this handle all cases, I've coded it to expect
    that difference.
3.  I changed the baud rate of `esptool.py write_flash ...` from 115,200
    to 57,600, just because I don't yet have proper decoupling capacitors.
    (See [4 ways to eliminate ESP8266 resets](http://internetofhomethings.com/homethings/?p=396) for more info).


After installing `esp-open-sdk` and building
"...the self-contained, standalone toolchain+SDK", I am able to build this
example with:

    make

...which produces:

```
 486272 Nov  8 23:26 blinky
  33152 Nov  8 23:26 blinky-0x00000.bin
 194016 Nov  8 23:26 blinky-0x10000.bin
   2236 Nov  8 23:26 blinky.o
```

I can then reset the device into "Flash" mode and write the firmware with:

    make flash

...after which the LED starts flashing, as per the code.

## `04` - Basic PWM example

This is a modified version of `03` which runs its timer at 1000Hz and uses it
to do basic PWM (Pulse-Width Modulation).

It does OK, but apparently there are better ways to do this with the ESP8266.

The main reason for this test was to test out a modified programming adapter
that I made. It's much smaller, so it is able to run at a faster data rate
(up to 230kbit instead of 57,600).

## `05` - 

(TBC)

