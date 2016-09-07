class HttpRecognizer
  C_slash = '/'.freeze
  C1_0 = '1.0'.freeze
  C1_1 = '1.1'.freeze
  CConnection_close = "Connection: close\r\n".freeze
  CConnection_KeepAlive = "Connection: Keep-Alive\r\n".freeze
  Crn = "\r\n".freeze
  Crnrn = "\r\n\r\n".freeze
  C_empty = ''.freeze
  C_percent = '%'.freeze
  Cunknown_host = 'unknown host'.freeze
  C404Header = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n"
  C400Header = "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n"
end
