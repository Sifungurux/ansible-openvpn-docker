[![Build Status](https://travis-ci.org/Sifungurux/ansible-openvpn-docker.svg?branch=master)](https://travis-ci.org/Sifungurux/ansible-openvpn-docker)
# Openvpn project
**Configurating docker contained vpn server 
with a docker contained data container** 

Container is configured with ansible that at run time configure a openvpn
 service. Configuraion of the services is done in the default folder in the
main.yml file.

There are two ways of using this project at a openvpn container image build on Debian.

First is using it as a standalone image. 
Fork the repo to customize the server conf or just clone it to use the default settings. **See the default/main.yml for configuration**
If forked you need to change the test/dockerfile to match the your repo.

Manage containers - Multiple.
Can be used to kuberneties to service multiple instance sharing storage space. (only server Certs and client configurations

Data storage:
1. standalone
Data contained inside to dockercontainer.
2. Manage 
One containing the the client certs and config and a client/server build the container containing cert data and the data from the client container

`docker create -v /etc/openvpn/clients --name client_datacontainer alpine`

`docker create -v /etc/openvpn/certs -volumes-from client_datacontainer --name ovpn_datacontainer alpine`

	1. Certs
		Contains server certificates.
	2. Clients
		Containing the client configurations and certs. Archived and compressed. 
		Supporsed to be share with a samba controlled share to allow users download own configurations.
	3. Config 
		Server configurations. Server.conf and server related configurations files. Ipp.txt and client IP configurations. Not yet implemented


Build the docker images

`docker build -t <your handle>/ovpn -f tests/Dockerfile .`

Next run/build the container
1. standalone
`docker run -itd --name openvpn --privileged --cap-add=NET_ADMIN <Containner name> ovpn`
2. Managed
`docker run -itd --volumes-from ovpn_datacontainer --name openvpn --privileged --cap-add=NET_ADMIN <Containner name> ovpn`

## Local testing with Lima

Vagrant has been replaced with [Lima](https://github.com/lima-vm/lima) for local testing. Lima runs a Debian 12 (bookworm) VM on macOS (Apple Silicon and Intel) without requiring VirtualBox or Vagrant. Ansible runs from the macOS host and connects to the VM over SSH — the VM is just a managed node.

### How it works

```
macOS host
├── ansible-playbook (runs here)
│   └── SSH → lima-openvpn-test (Debian 12, 192.168.5.15 / 192.168.105.x)
│               ├── installs openvpn + easy-rsa
│               ├── builds PKI (CA, server cert, DH params, ta.key)
│               └── starts openvpn@server
└── SSH → lima-openvpn-client (Debian 12, 192.168.105.y)
            ├── installs openvpn
            ├── receives client cert/key/config from server via Ansible fetch
            └── connects to server → tun0 up → ping 192.168.30.1 ✓
```

Lima generates an SSH config per VM (`limactl show-ssh <vm> --format config`). The Makefile writes both configs into a single temp file and passes it to Ansible via `ansible_ssh_extra_args='-F /tmp/...'` so both VMs are reachable without manual SSH setup.

### Prerequisites

```bash
brew install lima ansible socket_vmnet
sudo brew services start socket_vmnet   # required for VM-to-VM networking
```

### Run the tests

```bash
# Server-only (installs role, starts OpenVPN)
make test-start   # boot Debian 12 server VM
make test-run     # configure server, build PKI, start openvpn@server
make test-stop    # destroy server VM

# End-to-end tunnel test
make test-start && make test-run        # configure server first
make client-start                       # boot Debian 12 client VM
make client-run                         # generate client cert on server,
                                        # distribute certs to client,
                                        # start OpenVPN client,
                                        # assert tun0 up + ping 192.168.30.1
make client-stop                        # destroy client VM

# Full cycle in one command
make test-e2e
```

### Networking

Each Lima VM gets two network interfaces:

| Interface | Network | Purpose |
|---|---|---|
| `eth0` | `192.168.5.x` | vzNAT — outbound internet (apt, etc.) |
| `lima1` | `192.168.105.x` | socket_vmnet shared — VM-to-VM |

The OpenVPN server binds to all interfaces (`0.0.0.0:1194`) and the client connects via `lima1`. The VPN tunnel itself uses `192.168.30.0/28` (configurable in `defaults/main.yml`).

### Build the Docker image

```bash
make docker-build
```

## Testing with Docker

You can test the full server + client flow using two Docker containers on a shared bridge network.

### Build and start the server

```bash
make docker-build
docker network create vpn-test
docker run -d --name openvpn-server --cap-add=NET_ADMIN --network vpn-test -p 1194:1194/udp openvpn
```

### Generate a client certificate

```bash
docker exec openvpn-server ansible-playbook \
  /etc/ansible/roles/ansible-openvpn-docker/tests/main.yml \
  -i 'localhost,' --connection=local --tags "addclient" \
  -e "client=testclient" -e "local=container" \
  -e "remote_server=$(docker inspect openvpn-server --format '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' | awk '{print $NF}')"
```

### Extract the client bundle

```bash
docker cp openvpn-server:/etc/openvpn/clients/testclient/testclient.tar.gz /tmp/
mkdir -p ~/testclient && tar -xzf /tmp/testclient.tar.gz -C ~/testclient
```

### Build and run the client container

Create `~/testclient/Dockerfile`:

```dockerfile
FROM openvpn
COPY . /vpn/
CMD ["bash", "-c", "mkdir -p /dev/net && [ ! -c /dev/net/tun ] && mknod /dev/net/tun c 10 200; cd /vpn && openvpn --config client.conf"]
```

Update the remote address and connect:

```bash
SERVER_IP=$(docker inspect openvpn-server --format '{{(index .NetworkSettings.Networks "vpn-test").IPAddress}}')
sed -i "s/^remote .*/remote $SERVER_IP 1194/" ~/testclient/client.conf

docker build -t openvpn-client ~/testclient/
docker run --rm --cap-add=NET_ADMIN --network vpn-test openvpn-client
```

### Expected output

```
[VPN] Peer Connection Initiated with [AF_INET]<server_ip>:1194
TUN/TAP device tun0 opened
net_addr_ptp_v4_add: 192.168.30.6 peer 192.168.30.5 dev tun0
Initialization Sequence Completed
```

The client receives a VPN IP in the `192.168.30.0/28` range and the tunnel is up.

### Clean up

```bash
docker stop openvpn-server
docker network rm vpn-test
docker rmi openvpn-client
```

## Troubleshooting

### socket_vmnet not running — VMs get the same IP

**Symptom:** Both VMs show `192.168.5.15`, client gets `ECONNREFUSED`

Lima's default `vzNAT` isolates each VM behind its own NAT. VM-to-VM communication requires `socket_vmnet` to be running so the shared `lima1` interface gets a unique IP per VM.

```bash
# Check if socket is present
ls /var/run/lima/socket_vmnet.shared && echo "running" || echo "not running"

# Start it
sudo brew services start socket_vmnet

# Then recreate both VMs
make test-stop && make client-stop
make test-start && make test-run
make client-start && make client-run
```

### tun0 does not come up

**Symptom:** `Timeout when waiting for file /sys/class/net/tun0`

The OpenVPN client log is printed automatically. Check the remote IP being used:

```bash
# Should show 192.168.105.x, not a public IP
limactl shell openvpn-client -- cat /etc/openvpn/client/client.conf | grep ^remote
```

If the IP is wrong, the `lineinfile` task that patches `client.conf` may not have run. Re-run `make client-run`.

### OpenVPN server not listening / ECONNREFUSED on correct IP

**Symptom:** Log shows correct `192.168.105.x:1194` but still `ECONNREFUSED`

```bash
# Check server is listening on 0.0.0.0 (not just eth0)
limactl shell openvpn-test -- sudo ss -ulnp | grep 1194

# Check service is active
limactl shell openvpn-test -- systemctl status openvpn@server

# Restart if needed
limactl shell openvpn-test -- sudo systemctl restart openvpn@server
```

The service is `openvpn@server` (not `openvpn`) on Debian 12. The server binds to `0.0.0.0` so it accepts connections on all interfaces including `lima1`.

### Ping fails but tun0 is up

**Symptom:** tun0 comes up but `ping 192.168.30.1` fails

Check IP forwarding is enabled on the server VM:

```bash
limactl shell openvpn-test -- cat /proc/sys/net/ipv4/ip_forward
# Should be 1 — set via /etc/sysctl.d/99-openvpn.conf at provision time
```

If `0`, enable it manually:
```bash
limactl shell openvpn-test -- sudo sysctl -w net.ipv4.ip_forward=1
```
