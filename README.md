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
