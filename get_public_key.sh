#!/bin/bash

{

#check if curl or wget exists

if [ ! -x /usr/bin/curl ]; then
	echo "Error: curl not found."
	exit 1
fi
if [ ! -x /usr/bin/wget ]; then
	echo "Error: wget not found."
	# TODO: Install wget?
	exit 1
fi

hash=$(cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c6)

#TODO: Don't think this is needed.
virt_env_name='secretsmanager'${hash}''

set_locale()
{
	export LC_ALL="en_US.UTF-8"
	export LC_CTYPE="en_US.UTF-8"
	sudo dpkg-reconfigure locales --default-priority
}

install_pip()
{
	sudo apt install python -y
	sudo curl -s https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
	sudo python /tmp/get-pip.py
	sudo rm -f /tmp/get-pip.py
}

install_virtualenv()
{
	sudo pip install virtualenv 2>&1
}

install_aws_cli()
{
	sudo /tmp/${virt_env_name}/bin/pip install --upgrade awscli 2>&1
}

install_jq()
{
	sudo wget -O /tmp/${virt_env_name}/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64; chmod +x /tmp/${virt_env_name}/bin/jq
}

###################################################################################################################################################################

#requirements jq, awscli, python, pip

command -v pip >/dev/null 2>&1
if [ $? -ne 0 ]; then
        echo "Warning! pip not found. Installing and Retrying.."
        install_pip
        command -v pip >/dev/null 2>&1
fi

command -v virtualenv >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Warning! virtualenv not found. Installing and Retrying.."
    install_virtualenv
    if [ $? -eq 0 ]; then
		echo 'virtualenv installed using pip'
	fi
fi

# Create a new virtual environment only if it doesn't already exist
if [ ! -d /tmp/${virt_env_name} ]; then
	virtualenv /tmp/${virt_env_name}
	if [ $? -ne 0 ]; then
		echo 'Some problem. Fix it'
		exit 1
	fi
fi

# Activate virtual env
source /tmp/${virt_env_name}/bin/activate
if [ $? -ne 0 ]; then
	echo 'Error! Problem with activating virtualenv'
fi

# Check if awscli version is latest
tmp=$(/tmp/${virt_env_name}/bin/aws --version 2>&1 )
awsversion=$(echo ${tmp%% *} | cut -c 9-)
if [ ${awsversion} == 1.16.96 ]; then
	echo 'compatible awscli version found'
else
	install_aws_cli
fi

if [ ! -x /usr/bin/jq ]; then
	echo "Warning! jq not found. Installing and Retrying.."
	install_jq
	if [ $? -eq 0 ]; then
		echo 'Success! jq installed in /tmp/'${virt_env_name}'/bin'
	fi
fi

# How do you know the Instance Details?

region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document/ | jq -r .region)
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

export AWS_DEFAULT_REGION=${region}

response=$(/tmp/${virt_env_name}/bin/aws secretsmanager get-secret-value --secret-id ${instance_id} | jq -r .SecretString | jq -r .public_key)
} &> /tmp/AuthorizedKeysCommand.stdout

echo ${response}
