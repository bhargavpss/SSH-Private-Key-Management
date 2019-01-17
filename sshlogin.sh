#!/bin/bash

# SSH Login Script

if [ -z $1 ]; then
	echo "Usage: $0 <instance_id>"
	exit 1
fi

# i-0cc7f7228502b682b
instance_id=$1

login_user='ubuntu'

if [ ! -x /usr/bin/curl ]; then
	echo "Error: curl not found."
	exit 1
fi

region=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | cut -c 1-9)

install_aws_cli()
{
	sudo apt install python -y
	sudo curl -s https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
	sudo python /tmp/get-pip.py
	sudo pip install awscli
}

export AWS_DEFAULT_REGION=${region}


command -v aws >/dev/null 2>&1

if [ $? -ne 0 ]; then
        echo "Warning! aws cli not found. Installing and Retrying.."
        install_aws_cli
        command -v aws >/dev/null 2>&1
fi

get_instance_private_dns()
{
	local result=$(aws ec2 describe-instances --filters "Name=instance-id,Values=${instance_id}" | jq -r .Reservations[].Instances[].NetworkInterfaces[].PrivateDnsName)
	private_dns=${result}
	return 0
}

get_instance_private_dns
if [ -z ${private_dns} ]; then
	echo Given InstanceId: \"$instance_id\" not found
	exit 1
fi

get_private_key()
{
	local result=$(aws secretsmanager get-secret-value --secret-id ${instance_id} | jq -r .SecretString | jq -r .private_key)
	encoded_key=${result}
	return 0
}

# fine name hash
hash=$(cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c6)
file_name='private_key'${hash}'.pem'

get_private_key
echo ${encoded_key} | base64 -d > ~/${file_name}
chmod 600 ~/${file_name}
ssh -i ~/${file_name} ${login_user}@${private_dns}; rm -f ~/${file_name}

