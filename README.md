# terraform-aws-cloudwatch-lambda-to-slack
This terraform scripts to deploy a Lambda function periodically triggered by CloudWatch Events. The Lambda Function retrieve your current month's AWS cost from Cost Explorer API responses and posts message to any Slack Channel using Incoming Webhooks.

## Flow Overview
![Image of Overview](https://github.com/yakumobooks/terraform-aws-cloudwatch-lambda-to-slack/blob/images/cloudwatch-lambda-to-slack.png)

This Lambda function is written in Python3. The Python program was created with reference to Blueprints.

## Slack Incoming Webhooks
See the links below.
- [Summary](https://get.slack.help/hc/en-us/articles/115005265063-Incoming-WebHooks-for-Slack)
- [API Documentation](https://api.slack.com/incoming-webhooks)

## How to Use
- Setup [Terraform](https://www.terraform.io/)
- In terraform.tfvars, you will set the channel of your choice and Webhook URL.
- The left side border color of the message changes with threshold of cost. (The unit is USD)
```
region               = "<REGION>"
slack_channel_name   = "<YOUR SLACK CHANNEL>"     # ex) general (without '#')
slack_webhook_url    = "<YOUR SLACK WEBHOOK URL>" # ex) hooks.slack.com/services/XXXXXXX (without 'https://')
cloudwatch_cron      = "cron(0 0 */3 * ? *)"      # CAUTION: Cost Explorer API cost for each API call is $0.01
lambda_function_name = "lambda-function"
lambda_handler_name  = "lambda_handler"
billing_threshold_warning = 80
billing_threshold_danger  = 100
```

## Notes
- AWS Key Management Service (KMS) costs $1/month.
- Cost Explorer API cost for each API call is $0.01.
- It does not correspond to the response of the multiple set of results of Cost Explorer API. See [get_cost_and_usage](http://boto3.readthedocs.io/en/latest/reference/services/ce.html)

## License
MIT