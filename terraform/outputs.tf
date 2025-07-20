output "raw_events_bucket" {
  description = "Input bucket for raw events"
  value       = aws_s3_bucket.raw_events.bucket
}

output "reports_bucket" {
  description = "Output bucket for daily reports"
  value       = aws_s3_bucket.reports.bucket
}

output "dynamodb_table" {
  description = "DynamoDB table for processed events"
  value       = aws_dynamodb_table.event_data.name
}

output "event_processor_lambda" {
  value = aws_lambda_function.event_processor.function_name
}

output "daily_report_lambda" {
  value = aws_lambda_function.daily_report.function_name
}

output "lambda_code_bucket" {
  description = "Bucket where Lambda ZIP code is uploaded"
  value       = aws_s3_bucket.lambda_code_bucket.bucket
}
