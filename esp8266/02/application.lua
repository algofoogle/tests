led = 4
ch1 = 1
ch2 = 2
ch3 = 5
ch4 = 6

gpio.mode(led, gpio.OUTPUT)
gpio.write(led, gpio.LOW)
tmr.delay(100000)
gpio.write(led, gpio.HIGH)

gpio.mode(ch1,gpio.OUTPUT)
gpio.mode(ch2,gpio.OUTPUT)
gpio.mode(ch3,gpio.OUTPUT)
gpio.mode(ch4,gpio.OUTPUT)
gpio.write(ch1,gpio.LOW)
gpio.write(ch2,gpio.LOW)
gpio.write(ch3,gpio.LOW)
gpio.write(ch4,gpio.LOW)

http_header = function(code, type) 
    return "HTTP/1.1 " .. code .. "\r\nConnection: close\r\nServer: anton-Luaweb\r\nContent-Type: " .. type .. "\r\n\r\n";  
end

send_file = function(conn, filename) 
    if file.open(filename, "r") then 
        --conn:send(responseHeader("200 OK","text/html")); 
        repeat  
        local line=file.readline()  
        if line then  
            conn:send(line); 
        end  
        until not line  
        file.close(); 
    else 
        conn:send(http_header("404 Not Found","text/html")); 
        conn:send("Page not found"); 
    end 
end 
 

if sv ~= nil then
    print("Closing existing TCP server")
    sv:close()
    sv = nil
end

sv=net.createServer(net.TCP)
print("Web server starting...")
sv:listen(80,function(conn)
    conn:on("receive", function(client,request)
        local _, _, method, path, vars = string.find(request, "([A-Z0-9]+) (.+)?(.+) HTTP");
        print(method)
        if (method == nil) then
            _, _, method, path = string.find(request, "([A-Z0-9]+) (.+) HTTP");
        end
        local _GET = {}
        if (vars ~= nil) then
            for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
                _GET[k] = v
            end
        end
        if path == "/" then
            print("(Index)")
            client:send(http_header("200 OK", "text/html"))
            send_file(client, "index.html")
        else
            local s = ((_GET.s == "1") and gpio.HIGH or gpio.LOW)
            if (path == "/1") then
                gpio.write(ch1, s)
            elseif (path == "/2") then
                gpio.write(ch2, s)
            elseif (path == "/3") then
                gpio.write(ch3, s)
            elseif (path == "/4") then
                gpio.write(ch4, s)
            else
                s = s .. "X"
            end
            print("CH" .. path .. "=" .. s)
            client:send(http_header("200 OK", "text/plain") .. "CH" .. path .. "=" .. s)
        end
        client:close();
        collectgarbage();
    end)
end)
