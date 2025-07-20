import json
import boto3
import uuid

dynamodb = boto3.resource('dynamodb')
import os
TABLE_NAME = os.environ.get('DYNAMODB_TABLE')

def lambda_handler(event, context):
    table = dynamodb.Table(TABLE_NAME)
    # S3 Event se file location nikaalo
    s3_event = event['Records'][0]['s3']
    bucket = s3_event['bucket']['name']
    key = s3_event['object']['key']

    s3 = boto3.client('s3')
    response = s3.get_object(Bucket=bucket, Key=key)

    data = response['Body'].read().decode('utf-8')
    event_json = json.loads(data)  # maan lo ek hi JSON object hai, ek event per file

    # Record banayein
    item = {
        'event_id': str(uuid.uuid4()),
        'user_id': event_json.get('user_id', ''),
        'event_type': event_json.get('event_type', ''),
        'event_timestamp': event_json.get('event_timestamp', ''),
        'details': json.dumps(event_json.get('details', {}))
    }

    table.put_item(Item=item)
    print(f"Processed event: {item}")
    return {
        'statusCode': 200,
        'body': 'Event processed and stored in DynamoDB'
    }
