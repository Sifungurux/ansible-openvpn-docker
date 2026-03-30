FROM debian:bookworm

#VOLUME ["/etc/openvpn/certs", "/etc/openvpn/clients"

RUN apt-get update && \
 apt-get -y upgrade && \
 apt-get install -y git ansible openvpn && \
 mkdir -p /etc/ansible/roles/ansible-openvpn-docker &&  \
 cd /etc/ansible/roles/ansible-openvpn-docker && \
 git clone https://github.com/Sifungurux/ansible-openvpn-docker.git . && \ 
 ansible-playbook tests/main.yml -i 'localhost,' --connection=local --skip-tags "addclient, docker"

 # Change this line to match your own repo if forked
EXPOSE 1194/tcp
EXPOSE 1194/udp
CMD ["ovpn"]
