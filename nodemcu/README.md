# NodeMCU tests

## My NodeMCU board

The board I'm testing with is [eBay item #142121272679](http://www.ebay.com.au/itm/142121272679): ESP12E "V3", branded with <http://wemos.cc>, "LoLin", and "Ver 0.1". For more info, see: <http://frightanic.com/iot/comparison-of-esp8266-nodemcu-development-boards/>

Apparently, the specific board I have is mentioned here: <http://frightanic.com/iot/comparison-of-esp8266-nodemcu-development-boards/#v3>
...with the key difference being pins 2 and 3 (assuming pin 1 is the top-left)
which are GND (`G`) and USB +V (`VU`) respectively:

[[https://github.com/algofoogle/tests/blob/master/nodemcu/esp8266-nodemcu-dev-kit-v3-pins.jpg]]

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

