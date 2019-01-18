import sys
import boto3
import base64
import traceback
from os import chmod
from Crypto.PublicKey import RSA

secretsmanager = boto3.client('secretsmanager')
ec2 = boto3.client('ec2')

def lambda_handler(event, context):
	resources = event['resources']
	try:
		response = secretsmanager.list_secrets()
	except:
		print traceback.format_exc()
	secretslist = {}
	for i in response['SecretList']:
		secretslist[i['Name']] = None

	if event['detail']['state'] == 'running':
		key = RSA.generate(2048)                   # Generating Key Pair
		private_key = key.exportKey('PEM')
		encoded_key = base64.b64encode(private_key) # base64 encode the private key with no wrap
		pubkey = key.publickey()
		public_key = pubkey.exportKey('OpenSSH')
		for arn in resources:
			instance_id = arn.split('/')[1]
			if instance_id in secretslist:            # Don't do anything if the key is already present. Could be a stopped instance which is just started
				continue
			else:
				try:
					response = ec2.describe_instances(
						InstanceIds=[
							instance_id,
    					],
					)
				except:
					print traceback.format_exec()

			found = False
			for i in  response['Reservations'][0]['Instances'][0]['Tags']:
				if i['Key'] == 'microservice':
					microservice = i['Value']
					found = True
					break
				else:
					continue
			if not found:
				microservice = 'general'

			try:		    
				response = secretsmanager.create_secret(
						Name=instance_id,
						Description='SSH Key Pair for Instance',
						SecretString='{"public_key":"'+public_key+'","private_key":"'+encoded_key+'"}',
						Tags=[
							{
								'Key': 'InstanceARN',
								'Value': arn
							},
							{
								'Key': 'microservice',
								'Value': microservice
							}
						]
				)
			except:
				print traceback.format_exec()

		return None

	elif event['detail']['state'] == 'terminated':
		for arn in resources:
			instance_id = arn.split('/')[1]
			if instance_id in secretslist:
				try:
					response = secretsmanager.delete_secret(
						SecretId=instance_id,
						RecoveryWindowInDays=7,
						ForceDeleteWithoutRecovery=False
					)
				except:
					print traceback.format_exec()
					
			else:                                # Don't do anything if the key is not present. Instance is not registered in SecretsManager
				continue
		
		return None



