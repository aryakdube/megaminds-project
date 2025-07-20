provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "raw_events" {
  bucket        = var.raw_events_bucket
  force_destroy = true
}

resource "aws_s3_bucket" "reports" {
  bucket        = var.reports_bucket
  force_destroy = true
}

resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket        = var.lambda_code_s3_bucket
  force_destroy = true
}

resource "aws_s3_object" "processor_lambda_zip" {
  bucket = aws_s3_bucket.lambda_code_bucket.bucket
  key    = var.event_processor_key
  source = "../processor_lambda.zip"
}

resource "aws_s3_object" "report_lambda_zip" {
  bucket = aws_s3_bucket.lambda_code_bucket.bucket
  key    = var.report_lambda_key
  source = "../report_lambda.zip"
}


resource "aws_dynamodb_table" "event_data" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"
  attribute {
    name = "event_id"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_execution" {
  name = "pipeline-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_access" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_lambda_function" "event_processor" {
  function_name = "event-processor-fn"
  handler       = "processor_lambda.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_execution.arn
  timeout       = 60

  s3_bucket = aws_s3_bucket.lambda_code_bucket.bucket
  s3_key    = var.event_processor_key

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.event_data.name
    }
  }
}

resource "aws_lambda_function" "daily_report" {
  function_name = "daily-report-fn"
  handler       = "report_lambda.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_execution.arn
  timeout       = 300

  s3_bucket = aws_s3_bucket.lambda_code_bucket.bucket
  s3_key    = var.report_lambda_key

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.event_data.name
      REPORT_BUCKET  = aws_s3_bucket.reports.bucket
    }
  }
}

resource "aws_s3_bucket_notification" "raw_events_trigger" {
  bucket = aws_s3_bucket.raw_events.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.event_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_lambda_permission" "allow_s3_invoke_processor" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_events.arn
}

resource "aws_cloudwatch_event_rule" "daily_schedule" {
  name                = "pipeline-daily-schedule"
  schedule_expression = "cron(30 19 * * ? *)" # 1am IST = 19:30 UTC previous day
}

resource "aws_cloudwatch_event_target" "invoke_report_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_schedule.name
  target_id = "daily_report_lambda"
  arn       = aws_lambda_function.daily_report.arn
}

resource "aws_lambda_permission" "allow_cw_invoke_report" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.daily_report.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_schedule.arn
}
