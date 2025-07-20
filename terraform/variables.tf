variable "region" {
  default = "us-east-1"
}

variable "raw_events_bucket" {
  default = "aryak-raw-events-bucket-demo-xyz123"   # make unique per AWS S3 requirements!
}

variable "reports_bucket" {
  default = "aryak-reports-bucket-demo-xyz123"
}

variable "dynamodb_table_name" {
  default = "event_data_table"
}

variable "lambda_code_s3_bucket" {
  description = "S3 bucket where Lambda .zip code is uploaded"
  default     = "lambda-code-bucket-aryak-20240722"
}


variable "event_processor_key" {
  description = "event processor lambda zip key"
  default     = "processor_lambda.zip"
}

variable "report_lambda_key" {
  description = "report lambda zip key"
  default     = "report_lambda.zip"
}
