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

Firstly, build the container that will hold the data

`docker create -v /etc/openvpn/certs -v /etc/openvpn/clients --name ovpn_datacontainer alpine')`

Next run/build the container

`docker run -itd --volumes-from ovpn_datacontainer --name openvpn_test --privileged --cap-add=NET_ADMIN jenkins/openvpn-auto setup`
