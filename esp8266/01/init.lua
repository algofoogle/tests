-- Load AP.SSID and AP.PASSWORD variables declared in secrets.lua.
-- This file should be kept secret:
dofile("secrets.lua")

-- This method is called to TRY and start the main app once we've
-- successfully connected to our AP (Access Point):
function startup()
    if file.open("init.lua") == nil then
        print("Aborting: init.lua has been deleted or renamed.")
    else
        print("startup(): Calling application.lua ...")
        file.close("init.lua")
        dofile("application.lua")
    end
end

print("Connecting to Wi-Fi access point: " .. AP.SSID .. "...")
wifi.setmode(wifi.STATION)
wifi.sta.config(AP.SSID, AP.PASSWORD)
-- wifi.sta.connect() not necessary because config() uses auto-connect=true by default

-- Start a timer to check our conneciton status every 1sec:
tmr.alarm(1, 1000, 1, function()
    if wifi.sta.getip() == nil then
        -- Still waiting for an IP:
        print("Waiting for IP address...")
    else
        -- Got an IP; we're connected.
        -- Stop the timer:
        tmr.stop(1)
        -- Show connection details:
        print("WiFi connection established. IP address: " .. wifi.sta.getip())
        print("You have 3 seconds to abort")
        print("Waiting...")
        -- Allow up to 3 seconds before calling our app.
        -- This gives some time for a debug console to rename "init.lua" to
        -- something else and hence abort execution of "application.lua",
        -- should that have some fatal error that causes the NodeMCU to reboot.
        tmr.alarm(0, 3000, 0, startup)
    end
end)
