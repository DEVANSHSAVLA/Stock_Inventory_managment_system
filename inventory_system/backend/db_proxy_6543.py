import socket
import threading

LOCAL_PORT = 6543
REMOTE_HOST = "db.bydmzdrrvubecejqldhv.supabase.co"
REMOTE_PORT = 6543

def handle_client(client_socket):
    try:
        remote_socket = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
        remote_socket.connect((REMOTE_HOST, REMOTE_PORT))
    except Exception as e:
        print(f"[!] Failed to connect to remote host: {e}")
        client_socket.close()
        return

    def forward(src, dst):
        try:
            while True:
                data = src.recv(4096)
                if not data:
                    break
                dst.sendall(data)
        except Exception:
            pass
        finally:
            src.close()
            dst.close()

    t1 = threading.Thread(target=forward, args=(client_socket, remote_socket))
    t2 = threading.Thread(target=forward, args=(remote_socket, client_socket))
    t1.start()
    t2.start()

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('0.0.0.0', LOCAL_PORT))
        server.listen(50)
        print(f"[*] Database proxy listening on IPv4 port {LOCAL_PORT} -> forwarding to {REMOTE_HOST}:{REMOTE_PORT} over IPv6...")
    except Exception as e:
        print(f"[!] Bind failed: {e}")
        return

    while True:
        try:
            client_sock, addr = server.accept()
            # print(f"[*] Connection accepted from {addr}")
            threading.Thread(target=handle_client, args=(client_sock,), daemon=True).start()
        except KeyboardInterrupt:
            break
        except Exception:
            pass

if __name__ == '__main__':
    main()
