import socket

def next_free_port(port=8000, max_port=8100):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM) # type: ignore
    while port <= max_port:
        try:
            sock.bind(('', port))
            sock.close()
            return port
        except OSError:
            port += 1
            
    raise IOError('no free ports in specified range')