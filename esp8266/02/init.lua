dofile("secrets.lua")

function startup()
    if file.open("init.lua") == nil then
        print("init.lua was deleted or renamed")
    else
        print("Calling application.lua ...")
        file.close("init.lua")
        dofile("application.lua")
    end
end

print("Connecting Wi-Fi: " .. AP.SSID)
wifi.setmode(wifi.STATION)
wifi.sta.config(AP.SSID, AP.PASSWORD)

tmr.alarm(1, 1000, 1, function()
    if wifi.sta.getip() == nil then
        print("Waiting for IP address...")
    else
        tmr.stop(1)
        print("WiFi connected. IP address: " .. wifi.sta.getip())
        print("You have 3 seconds to abort...")
        tmr.alarm(0, 3000, 0, startup)
    end
end)
