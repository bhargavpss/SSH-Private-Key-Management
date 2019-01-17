import boto3
import sys
import json
import base64

from Crypto.PublicKey import RSA

secrets_manager = boto3.client('secretsmanager')
ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    response = secrets_manager.list_secrets(
        MaxResults=99
    )
    secretslist = {}
    for i in response['SecretList']:
        secretslist[i['Name']] = None
    
    response = ec2.describe_instances(
        Filters=[
            {
                'Name': 'instance-state-name',
                'Values': [
                    'running','stopped'
                ]
            },
        ]
    )
    
    instancelist = []
    for i in response['Reservations']:
        j = i['Instances']
        for k in j:
             instancelist.append(k['InstanceId'])
    #print 'instancelist:', instancelist
    #print 'secretlist:', secretslist
    for instance_id in instancelist:
	if instance_id in secretslist:
            key = RSA.generate(2048)                   # Generating Key Pair
            private_key = key.exportKey('PEM')
            encoded_key = base64.b64encode(private_key) # base64 encode the private key with no wrap
            pubkey = key.publickey()
            public_key = pubkey.exportKey('OpenSSH')    
            response = secrets_manager.put_secret_value(
 	        SecretId=instance_id,
    	        SecretString='{"public_key":"'+public_key+'","private_key":"'+encoded_key+'"}',
    	        VersionStages=[
        	    'AWSCURRENT',
    	        ]
	    )
	  #  print response
	  #  print '\n'

	else:
	    continue

    return None

# lambda_handler({},None)
