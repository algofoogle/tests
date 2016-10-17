LED = {}
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
