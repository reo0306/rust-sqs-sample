locals {
  stage = "dev"
}

data "aws_sns_topic" "slack_notification" {
  name = "${local.stage}-slack-notification"
}

module "simple_notification_lambda" {
  source = "../../../modules/lambda_func"
  stage = local.stage
  function_name = "simple_notification"
  handler = "bootstrap"
  runtime = "provided.al2023"
  environment_variables = {
    SNS_TOPIC_ARN = data.aws_sns_topic.slack_notification.arn
  }
  timeout = 30
  iam_inline_policy_statements = [
    {
      actions = ["sns:Publish"]
      resources = [data.aws_sns_topic.slack_notification.arn]
      effect = "Allow"
    }
  ]
}

