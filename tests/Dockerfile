FROM debian:jessie

VOLUME ["/etc/openvpn/certs", "/etc/openvpn/clients"

RUN echo "deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main" >> /etc/apt/sources.list.d/ansible.list && \
 apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367 && \
 apt-get update && \
 apt-get -y upgrade && \
 apt-get install -y git ansible openvpn && \
 mkdir -p /etc/ansible/roles/ansible-openvpn-docker &&  \
 cd /etc/ansible/roles/ansible-openvpn-docker && \
 git clone https://github.com/Sifungurux/ansible-openvpn-docker.git . && \
 ansible-playbook tests/main.yml -i 'localhost,' --connection=local --skip-tags "addclient, docker"


#ADD scripts/setup /usr/local/bin/
#RUN chmod 700 /usr/local/bin/setup

EXPOSE 1194/tcp
EXPOSE 1194/udp
CMD ["ovpn"]
