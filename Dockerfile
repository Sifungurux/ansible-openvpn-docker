FROM debian:jessie

RUN echo "deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main" >> /etc/apt/sources.list.d/ansible.list && \
 apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367

RUN apt-get update && \
 apt-get -y upgrade && \
 apt-get install -y git ansible openvpn

ADD scripts/setup /usr/local/bin/
RUN chmod 700 /usr/local/bin/setup

EXPOSE 1194/tcp
EXPOSE 1194/udp
CMD ["ovpn"]
