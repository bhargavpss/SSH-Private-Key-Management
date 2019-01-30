#!/bin/bash

if [ -z $1 ]; then
	echo "Usage: $0 <instance_id>"
	exit 1
fi

if [ ! -d ~/.sshlogin ]; then
	mkdir ~/.sshlogin
fi

# SSH Login Script
{

instance_id=$1

login_user='ubuntu'

if [ ! -x /usr/bin/curl ]; then
	echo "Error: curl not found."
	exit 1
fi

read -p "enter AWS_ACCESS_KEY: " AWS_ACCESS_KEY_ID
read -p "enter AWS_SECRET_KEY: " AWS_SECRET_ACCESS_KEY

export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

install_jq()
{
	sudo wget -O /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64; sudo chmod +x /usr/local/bin/jq
}

install_pip()
{
	sudo apt install python -y
	sudo curl -s https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
	sudo python /tmp/get-pip.py
	sudo rm -f /tmp/get-pip.py
}

install_aws_cli()
{
	sudo pip install awscli --upgrade
}

get_instance_private_dns()
{
	local result=$(aws ec2 describe-instances --filters "Name=instance-id,Values=${instance_id}" | jq -r .Reservations[].Instances[].NetworkInterfaces[].PrivateDnsName)
	private_dns=${result}
	return 0
}

get_private_key()
{
	local result=$(aws secretsmanager get-secret-value --secret-id ${instance_id} | jq -r .SecretString | jq -r .private_key)
	encoded_key=${result}
	return 0
}

####################################################################################################################################

[[ ":$PATH:" != *":/usr/local/bin:"* ]] && PATH="${PATH}:/usr/local/bin/"

if [ -z $(command -v pip 2>&1) ]; then
    echo "Warning! pip not found. Installing and Retrying.."
    install_pip
    if [ $? -eq 0 ]; then
		echo 'Success! pip installed'
	fi  
fi

if [ -z $(command -v jq 2>&1) ]; then
	echo "Warning! jq not found. Installing and Retrying.."
	install_jq
	if [ $? -eq 0 ]; then
		echo 'Success! jq installed in /usr/local/bin/'
	fi
fi

command -v aws >/dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "Warning! aws cli not found. Installing and Retrying.."
    install_aws_cli
    if [ $? -eq 0 ]; then
		echo 'Success! awscli installed via pip'
	fi
fi

tmp=$(aws --version 2>&1 )
awsversion=$(echo ${tmp%% *} | cut -c 9-)
if [ ${awsversion} == 1.16.96 ]; then
	echo 'compatible awscli version found'
else
	install_aws_cli
fi

region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document/ | jq -r .region)

export AWS_DEFAULT_REGION=${region}

get_instance_private_dns
if [ -z ${private_dns} ]; then
	echo Given InstanceId $instance_id not found
	exit 1
fi

# fine name hash
hash=$(cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c6)
file_name='private_key'${hash}'.pem'

get_private_key
if [ -z ${encoded_key} ]; then
    exit 1
fi

echo ${encoded_key} | base64 --decode > ~/.sshlogin/${file_name}
chmod 600 ~/.sshlogin/${file_name}
} > ~/.sshlogin/sshlogin.stdout
ssh -i ~/.sshlogin/${file_name} ${login_user}@${private_dns} && rm -f ~/${file_name}

