#!/bin/bash

curl -s https://raw.githubusercontent.com/bhargavpss/SSH-Private-Key-Management/master/get_public_key.sh -o ./get_public_key.sh

chmod +x ./get_public_key.sh

mv ./get_public_key.sh /usr/local/bin/

echo '
AuthorizedKeysCommand /usr/local/bin/get_public_key.sh
AuthorizedKeysCommandUser root
' >> /etc/ssh/sshd_config

service sshd restart
