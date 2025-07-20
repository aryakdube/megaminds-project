import boto3
import json
import os
import csv
from datetime import datetime, timedelta, timezone

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')

TABLE_NAME = os.environ.get('DYNAMODB_TABLE')
REPORT_BUCKET = os.environ.get('REPORT_BUCKET')

def lambda_handler(event, context):
    try:
        table = dynamodb.Table(TABLE_NAME)
        # Calculate previous day's date (in UTC)
        today = datetime.now(timezone.utc).date()
        yesterday = today - timedelta(days=1)
        y_str = str(yesterday)

        # Scan all items from DynamoDB (for demo)
        response = table.scan()
        items = response.get('Items', [])

        # Filter yesterday's events
        daily_events = [i for i in items if i.get('event_timestamp', '').startswith(y_str)]
        total_logins = sum(1 for i in daily_events if i['event_type'] == "login")
        total_purchases = sum(1 for i in daily_events if i['event_type'] == "purchase")
        total_revenue = 0
        product_count = dict()
        for i in daily_events:
            if i['event_type'] == "purchase":
                details = json.loads(i.get('details', '{}'))
                total_revenue += details.get('price', 0) * details.get('quantity', 1)
                prod_id = details.get('product_id', '-')
                product_count[prod_id] = product_count.get(prod_id, 0) + 1

        # Top Product(s)
        if product_count:
            top_products = sorted(product_count, key=lambda x: product_count[x], reverse=True)[:3]
            top_products_str = ', '.join(top_products)
        else:
            top_products_str = "-"

        # Prepare CSV data
        csv_header = ["Date","Total Logins","Total Purchases","Total Revenue","Top Products"]
        csv_rows = [ [y_str, total_logins, total_purchases, f"{total_revenue:,.2f}", top_products_str] ]
        csv_content = ""
        for row in [csv_header] + csv_rows:
            csv_content += (",".join([str(x) for x in row]) + "\n")

        # S3 key for report
        report_key = f"user_activity_summary_{y_str}.csv"
        s3.put_object(Bucket=REPORT_BUCKET, Key=report_key, Body=csv_content.encode("utf-8"))
        print(f"Report generated: s3://{REPORT_BUCKET}/{report_key}")
        return {
            'statusCode': 200,
            'body': f"Report generated on s3://{REPORT_BUCKET}/{report_key}"
        }
    except Exception as e:
        print(f"Error generating report: {e}")
        return {
            'statusCode': 500,
            'body': f"Report failed: {e}"
        }
