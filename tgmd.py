import time
import os
import fcntl
import socket
import struct
import threading

mcast_group_ip = '224.1.1.1'
mcast_group_port = 23456


def socket_init():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.bind((mcast_group_ip, mcast_group_port))
    mreq = struct.pack("=4sl", socket.inet_aton(
        mcast_group_ip), socket.INADDR_ANY)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)
    return sock


class send(threading.Thread):
    def __init__(self, *args, **kwargs):
        super(send, self).__init__(*args, **kwargs)
        self.__running = threading.Event()
        self.__running.set()
        self.message = ''

    def run(self):
        while self.__running.isSet():
            self.sock.sendto(self.message.encode(),
                             (mcast_group_ip, mcast_group_port))
            time.sleep(10)

    def stop(self):
        self.__running.clear()


class recv(threading.Thread):
    def __init__(self, *args, **kwargs):
        super(recv, self).__init__(*args, **kwargs)
        self.__running = threading.Event()
        self.__running.set()
        self.server_ip = ''
        self.ips = []

    def run(self):
        while self.__running.isSet():
            try:
                message, addr = self.sock.recvfrom(1024)
                if '' not in message.decode():
                    self.server_ip = message.decode()
                    return message.decode()
                self.ips.append(addr[0])
            except:
                pass

    def stop(self):
        self.__running.clear()


def get_ip():
    net_dev = os.listdir('/sys/class/net')
    if 'lo' in net_dev:
        net_dev.remove('lo')
    ifname = net_dev[0]
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    inet = fcntl.ioctl(s.fileno(), 0x8915, struct.pack(
        '256s',  bytes(ifname[:15], 'utf-8')))
    return socket.inet_ntoa(inet[20:24])


def str_int(ip):
    return int(ip.replace('.', ''))


if __name__ == "__main__":
    sock = socket_init()

    send_thread = send()
    send_thread.sock = sock
    send_thread.start()

    recv_thread = recv()
    recv_thread.sock = sock
    recv_thread.start()

    # 120秒没有新节点加入则放弃等待
    node_ips = []
    while True:
        time.sleep(120)
        print(node_ips)
        if recv_thread.server_ip:
            server_ip = recv_thread.server_ip
            break
        if tuple(node_ips) == tuple(recv_thread.ips):
            node_ips = list(tuple(recv_thread.ips))
            node_ips.sort(key=str_int)
            server_ip = node_ips[-1]
            break
        else:
            node_ips = recv_thread.ips

    f = open(".env", 'a')
    f.write(f"\nserverip={server_ip}\n")
    local_ip = get_ip()
    if server_ip == local_ip:
        print('is server')
        send_thread.message = local_ip
        recv_thread.stop()
        f.write(f"\nis_server=true\n")
        f.close()
        send_thread.join()
    else:
        send_thread.stop()
        recv_thread.stop()
        send_thread.join()
        recv_thread.join()
        f.write(f"\nis_server=false\n")
        f.close()
        exit()