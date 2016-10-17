function http_404(sck)
	out = "HTTP/1.0 404 Not Found\r\nContent-Type: text/html\r\n\r\n"
	out = .. "<html><body><h1>404 Not Found</h1><p>Sorry.</p></body></html>"
	sck:send(out)
end
