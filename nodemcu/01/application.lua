dofile("gpio.lua")
dofile("web.lua")

print("Initializing light-switch web server...")
-- Flash LED for a moment:
led_set(LED.on)
tmr.delay(100000) -- 100,000us (100ms)
led_set(LED.off)

-- Check if we already have a web server:
if HTTPD == nil then
    print("Assuming no existing TCP server...")
else
    print("Closing existing TCP server...")
    HTTPD:close()
    HTTPD = nil
end

-- EXPERIMENTAL:
-- ledcount_init() is used to prep D0-D3 for output, so we can drive LEDs on them:
function ledcount_init()
    gpio.mode(1, gpio.OUTPUT)
    gpio.mode(2, gpio.OUTPUT)
end
-- ledcount_update(n) shows the lower 4 bits of "n" on D0 (LSB) to D3 (MSB):
function ledcount_update(n)
    -- NOTE: Inverted logic for these LEDs:
    gpio.write(1, (bit.band(n,1)==1) and gpio.LOW or gpio.HIGH )
    gpio.write(2, (bit.band(n,2)==2) and gpio.LOW or gpio.HIGH )
end
ledcount_init()


-- create the HTTP server:
print("About to create HTTP server: http://" .. wifi.sta.getip())
HTTPD = net.createServer(net.TCP)
print("Listen on port 80...")
reqid = 0

HTTPD:listen(80, function(conn)

    conn:on("receive", function(sck, payload)
        reqid = reqid + 1
        ledcount_update(reqid)

        if payload:find("GET /on") then
            print(reqid, "Turning LED ON")
            led_set(LED.on)
        elseif payload:find("GET /off") then
            print(reqid, "Turning LED off")
            led_set(LED.off)
        elseif payload:find("GET / ") then
            print(reqid, "LED is " .. (LED.state == LED.off and "off" or "ON"))
        else
            print(reqid, "Returned HTTP 404", payload)
            http_404(sck)
            return
        end
        page = [[
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style type="text/css">
            body,input,select {
                font-family: Helvetica, Arial, sans-serif;
                font-size: 30px;
            }
            .led-on input {
                border-radius: 30px;
                border: 7px solid #36f;
                border-left: 50px solid #36f;
                background-color: #def;
                color: #36f;
            }
            .led-off input {
                border-radius: 30px;
                border: 7px solid #ccc;
                border-right: 50px solid #ccc;
                color: #666;
                background-color: #eee;
            }
            input {
                padding: 0;
                xxtext-align: center;
                width: 150px;
            }
            </style>
            </head>
            <body>
            <h1>Anton's LED switch</h1>
            <form method="get" action="/]]
        this_state = ((LED.state == LED.on) and "on" or "off")
        next_state = ((LED.state == LED.on) and "off" or "on")
        page = page .. next_state
        page = page .. '" class="led-' .. this_state .. '">'
        page = page .. '<input type="submit" value="' .. this_state .. '" />'
        page = page .. [[
            </form>
            </body>
            </html>
        ]]
        http_header = "HTTP/1.0 200 OK\r\nContent-Type: text/html\r\n\r\n"
        sck:send(http_header .. page)
    end) -- conn:on("receive"...)

    conn:on("sent", function(sck) sck:close() end)

end) -- HTTPD:listen(...)

