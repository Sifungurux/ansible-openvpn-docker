FROM debian:bookworm

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y ansible openvpn easy-rsa python3 python3-apt

COPY . /etc/ansible/roles/ansible-openvpn-docker/

RUN cd /etc/ansible/roles/ansible-openvpn-docker && \
    ansible-playbook tests/main.yml \
      -i 'localhost,' \
      --connection=local \
      --skip-tags "addclient,docker" \
      -e "local=container"

EXPOSE 1194/tcp
EXPOSE 1194/udp
CMD ["ovpn"]
