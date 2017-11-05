# Openvpn project
**Configurating docker contained vpn server 
with a docker contained data container** 

Container is configured with ansible that at run time configure a openvpn
 service. Configuraion of the services is done in the default folder in the
main.yml file.

Setup script will git clone or git pull the reposity to the container and execute
then ovpn script to setup /dev/net/tun and start the service.

Service will run when container is run. Data will be storage in a persistant
 data storage in a container.

Build the docker images to customize it or pull from docker.hub
`docker build -t <name> .`


Firstly, build the container that will hold the data

`docker create -v /etc/openvpn/certs -v /etc/openvpn/clients -v /etc/openvpn/config --name ovpn_datacontainer alpine')`

1. Certs
	Contains server certificates.
2. Clients
	Containing the client configurations and certs. Archived and compressed. 
	Supporsed to be share with a samba controlled share to allow users download own configurations.
3. Config 
	Server configurations. Server.conf and server related configurations files. Ipp.txt and client IP configurations.

Next run/build the container

`docker run -itd --volumes-from ovpn_datacontainer --name openvpn --privileged --cap-add=NET_ADMIN <name> setup`
