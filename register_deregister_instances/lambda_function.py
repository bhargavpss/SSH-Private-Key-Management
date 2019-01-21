import sys
import boto3
import base64
import traceback
from os import chmod
from botocore.exceptions import ClientError
from Crypto.PublicKey import RSA

secretsmanager = boto3.client('secretsmanager')
ec2 = boto3.client('ec2')

def lambda_handler(event, context):
	resources = event['resources']

	if event['detail']['state'] == 'running':
		# Generating Key Pair
		key = RSA.generate(2048)
		private_key = key.exportKey('PEM')
		# base64 encode the private key with no wrap
		encoded_key = base64.b64encode(private_key)
		pubkey = key.publickey()
		public_key = pubkey.exportKey('OpenSSH')
		
		for arn in resources:
			instance_id = arn.split('/')[1]
			try:
				response = ec2.describe_instances(
					InstanceIds=[
						instance_id,
    					],
				)
			except ClientError as e:
				raise e

			microservice_tag_exists = False
			for i in  response['Reservations'][0]['Instances'][0]['Tags']:
				if i['Key'] == 'microservice':
					microservice = i['Value']
					microservice_tag_exists = True
					break
				else:
					continue
			if not microservice_tag_exists:
				# Tagging all untagged instances with 'general'
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
			except ClientError as e:
                                if e.response['Error']['Code'] == "ResourceExistsException":
                                        # Don't do anything if the secret is already present.
                                        # Could be a stopped instance which is just started
                                        continue
				else:
					raise e

		return None

	elif event['detail']['state'] == 'terminated':
		for arn in resources:
			instance_id = arn.split('/')[1]
			try:
				response = secretsmanager.delete_secret(
					SecretId=instance_id,
					RecoveryWindowInDays=7,
					ForceDeleteWithoutRecovery=False
				)
			except ClientError as e:
				if e.response['Error']['Code'] == 'ResourceNotFoundException':
					# Don't do anything if the secret is not present
					# Instance may not have registered in SeretsManager
					continue
				else:
					raise e
		
		return None
