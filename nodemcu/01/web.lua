function http_404(sck)
	sck:send(
		"HTTP/1.0 404 Not Found\r\nContent-Type: text/html\r\n\r\n" ..
		"<html><body><h1>404 Not Found</h1><p>Sorry.</p></body></html>"
	)
end
