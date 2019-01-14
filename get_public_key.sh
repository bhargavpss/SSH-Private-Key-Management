#!/bin/bash
{

#check if curl or wget exists

if [ ! -x /usr/bin/curl ]; then
	echo "Error: curl not found."
	exit 1
fi

install_aws_cli()
{
	sudo apt install python -y
	sudo curl -s https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
	sudo python /tmp/get-pip.py
	sudo pip install awscli
}

#requirements jq, awscli

command -v aws >/dev/null 2>&1

if [ $? -ne 0 ]; then
        echo "Warning! aws cli not found. Installing and Retrying.."
        install_aws_cli
        command -v aws >/dev/null 2>&1
fi

if [ ! -x /usr/bin/jq ]; then
	echo "Warning! jq not found. Installing and retrying.."
	sudo add-apt-repository ppa:eugenesan/ppa -y
	sudo apt-get update -y && sudo apt-get install jq -y
	#sudo apt install jq -y
fi

# How do you know the Instance Details?

region=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | cut -c 1-9)
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id) # i-0cc7f7228502b682b

export AWS_DEFAULT_REGION=${region}

response=$(aws secretsmanager get-secret-value --secret-id ${instance_id} | jq -r .SecretString | jq -r .public_key)
} > /tmp/AuthorizedKeysCommand.stdout

echo ${response}
