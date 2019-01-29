#!/bin/bash

echo '
export LC_ALL="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
sudo dpkg-reconfigure locales --default-priority
' >> /root/.bashrc

curl -s https://raw.githubusercontent.com/bhargavpss/SSH-Private-Key-Management/master/get_public_key.sh -o ./get_public_key.sh

chmod +x ./get_public_key.sh

mv ./get_public_key.sh /usr/local/bin/

echo '
AuthorizedKeysCommand /usr/local/bin/get_public_key.sh
AuthorizedKeysCommandUser root
' >> /etc/ssh/sshd_config

service sshd restart
