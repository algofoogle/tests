LED = {}
-- Pin "4" corresponds with D4 on the NodeMCU devkit breakout board.
-- Note that apparently this is "GPIO2". See:
-- https://raw.githubusercontent.com/algofoogle/tests/master/nodemcu/esp8266-nodemcu-dev-kit-v3-pins.jpg
-- ...and: https://nodemcu.readthedocs.io/en/master/en/modules/gpio/
LED.pin = 4 
LED.off = gpio.HIGH
LED.on = gpio.LOW
LED.state = LED.off

guid = 0

function led_init()
    gpio.mode(LED.pin, gpio.OUTPUT)
end

function led_set(state)
	LED.state = state
    gpio.write(LED.pin, state)
end

led_init()
