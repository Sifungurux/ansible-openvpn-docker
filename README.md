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

Vagrant has been replaced with [Lima](https://github.com/lima-vm/lima) for local testing. Lima runs a Debian 12 (bookworm) VM on macOS (Apple Silicon and Intel) without requiring VirtualBox or Vagrant.

### Prerequisites

```bash
brew install lima ansible
```

### Run the tests

```bash
# Full cycle (start VM → run role → destroy VM)
make test

# Or step by step
make test-start   # boot Debian 12 Lima VM
make test-run     # run ansible-openvpn-docker role against the VM
make test-stop    # destroy the VM
```

### Build the Docker image

```bash
make docker-build
```

The Lima VM config is at `tests/lima/openvpn-test.yaml`. The Vagrantfile is kept for reference but is no longer maintained.

## End-to-end testing with a client VM

A second Lima VM (`tests/lima/openvpn-client.yaml`) acts as an OpenVPN client and verifies the tunnel comes up against the server VM.

```bash
# Start server VM and configure it first
make test-start
make test-run

# Then run the client cycle
make client-start   # boot Debian 12 client VM
make client-run     # generate client cert, distribute certs, start tunnel, assert ping
make client-stop    # destroy client VM

# Or the full end-to-end cycle in one command
make test-e2e
```

### Prerequisites for end-to-end testing

VM-to-VM networking requires `socket_vmnet`. Install and start it once:

```bash
brew install socket_vmnet
sudo launchctl load /opt/homebrew/Cellar/socket_vmnet/1.2.2/share/doc/socket_vmnet/launchd/io.github.lima-vm.socket_vmnet.plist
```

Both Lima VM configs use `networks: [{lima: shared}]` which relies on `socket_vmnet` being available.

## Troubleshooting

### tun0 does not come up

**Symptom:** `Timeout when waiting for file /sys/class/net/tun0`

Check the OpenVPN client log — it is printed automatically by the `client-run` playbook. Common causes:

**Client connecting to public IP instead of Lima IP**
The `client.conf` template can resolve to the server's public IP via `ansible_local.server.remote_ip`. The test playbook patches the `remote` line using `lineinfile` with `ansible_facts['eth0']['ipv4']['address']`. If you see the wrong IP in the log, verify the server VM's eth0:
```bash
limactl shell openvpn-test -- ip -4 addr show eth0
```

**Both VMs have the same IP (ECONNREFUSED)**
Lima's default `vzNAT` gives each VM an isolated NAT — VMs cannot reach each other and both get `192.168.5.15`. Fix: install and start `socket_vmnet` (see prerequisites above), then recreate the VMs with `make test-stop && make test-start`.

**OpenVPN server not running on server VM**
On Debian 12 the service is `openvpn@server`, not `openvpn`. Verify:
```bash
limactl shell openvpn-test -- systemctl status openvpn@server
# Start manually if needed:
limactl shell openvpn-test -- sudo systemctl start openvpn@server
```

**Wrong service name caused by stale server run**
If `make test-run` was executed before the `openvpn@server` fix, the service was never started. Run `make test-run` again after the fix to apply the corrected `install.yml`.
