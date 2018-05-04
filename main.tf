variable "region"                    {}
variable "slack_channel_name"        {}
variable "slack_webhook_url"         {}
variable "cloudwatch_cron"           {}
variable "lambda_function_name"      {}
variable "lambda_handler_name"       {}
variable "billing_threshold_warning" {}
variable "billing_threshold_danger"  {}

provider "aws" {
  region = "${var.region}"
}

resource "aws_kms_key" "key" {
  description = "slack webhook encrypt"
  is_enabled  = true
}

data "aws_kms_ciphertext" "kms_cipher" {
  key_id    = "${aws_kms_key.key.key_id}"
  plaintext = "${var.slack_webhook_url}"
}

data "archive_file" "slack" {
  type        = "zip"
  source_file = "lambda/${var.lambda_function_name}.py"
  output_path = "lambda/${var.lambda_function_name}.zip"
}

data "aws_iam_policy_document" "lambda_slack_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_slack_role" {
  name               = "LambdaSlackExcecute"
  assume_role_policy = "${data.aws_iam_policy_document.lambda_slack_role.json}"
}

data "aws_iam_policy_document" "lambda_slack_policy" {
  statement {
    sid       = "1"
    actions   = ["kms:Decrypt"]
    effect    = "Allow"
    resources = ["${aws_kms_key.key.arn}"]
  }

  statement {
    sid       = "2"
    actions   = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid       = "3"
    actions   = ["ce:GetCostAndUsage"]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_slack_policy" {
  name   = "lambda_slack_policy"
  policy = "${data.aws_iam_policy_document.lambda_slack_policy.json}"
}

resource "aws_iam_role_policy_attachment" "lambda_slack_policy" {
  role       = "${aws_iam_role.lambda_slack_role.name}"
  policy_arn = "${aws_iam_policy.lambda_slack_policy.arn}"
}

resource "aws_lambda_function" "slack" {
  filename         = "${data.archive_file.slack.output_path}"
  source_code_hash = "${data.archive_file.slack.output_base64sha256}"
  function_name    = "${var.lambda_function_name}"
  role             = "${aws_iam_role.lambda_slack_role.arn}"
  handler          = "${var.lambda_function_name}.${var.lambda_handler_name}"
  runtime          = "python3.6"
  environment {
    variables = {
      slackChannel        = "${var.slack_channel_name}",
      kmsEncryptedHookUrl = "${data.aws_kms_ciphertext.kms_cipher.ciphertext_blob}",
      thresholdWarning    = "${var.billing_threshold_warning}",
      thresholdDanger     = "${var.billing_threshold_danger}"
    }
  }
}

resource "aws_cloudwatch_event_rule" "billing_report" {
  name                = "billing_report_to_slack"
  description         = "billing report event trigger"
  schedule_expression = "${var.cloudwatch_cron}"
}

resource "aws_cloudwatch_event_target" "billing_report" {
  rule      = "${aws_cloudwatch_event_rule.billing_report.name}"
  target_id = "${aws_cloudwatch_event_rule.billing_report.name}"
  arn       = "${aws_lambda_function.slack.arn}"
}

resource "aws_lambda_permission" "cloudwatch_execution" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.slack.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.billing_report.arn}"
}
