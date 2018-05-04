region               = "<REGION>"
slack_channel_name   = "<YOUR SLACK CHANNEL>"     # ex) general (without '#')
slack_webhook_url    = "<YOUR SLACK WEBHOOK URL>" # ex) hooks.slack.com/services/XXXXXXX (without 'https://')
cloudwatch_cron      = "cron(0 0 */3 * ? *)"      # CAUTION: Cost Explorer API cost for each API call is $0.01
lambda_function_name = "lambda-function"
lambda_handler_name  = "lambda_handler"
billing_threshold_warning = 80
billing_threshold_danger  = 100
