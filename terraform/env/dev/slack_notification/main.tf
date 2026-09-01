locals {
  stage = "dev"
  slack_team_id = "T02V1J7HUDU" # Slack ワークスペースID
  notification_slack_channel_id = "C02VAHNU4HJ" # SlackチャンネルID
}

resource "aws_sns_topic" "slack_notification" {
  name = "${local.stage}-slack-notification"
}

# Amazon Q Develop用のIAMロールの信頼関係ポリシー
data "aws_iam_policy_document" "assume_role_chatbot" {
    statement {
        actions = ["sts:AssumeRole"] # ロール引受アクション
        effect = "Allow"
        principals {
          type = "Service"
          identifiers = ["chatbot.amazonaws.com"]
        }
    }
}

# Amazon Q Develop用のIAMロールを作成
resource "aws_iam_role" "chatbot" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_chatbot.json
}

# AWS管理ポリシーの参照
data "aws_iam_policy" "amazonq_developer" {
    name = "AmazonQDeveloperAccess"
}

data "aws_iam_policy" "cw_readonly_access" {
    name = "CloudWatchReadOnlyAccess"
}

resource "aws_iam_role_policy_attachments_exclusive" "chatbot" {
    role_name = aws_iam_role.chatbot.name
    policy_arns = [
        data.aws_iam_policy.amazonq_developer.arn,
        data.aws_iam_policy.cw_readonly_access.arn
    ]
}

# AWS読み取り専用ポリシーの参照
data "aws_iam_policy" "readonly_access" {
    name = "ReadOnlyAccess"
}

# Slackチャンネル設定
resource "aws_chatbot_slack_channel_configuration" "notification" {
  configuration_name = "${local.stage}-notification"
  guardrail_policy_arns = [data.aws_iam_policy.readonly_access.arn]
  iam_role_arn       = aws_iam_role.chatbot.arn
  slack_channel_id   = local.notification_slack_channel_id
  slack_team_id = local.slack_team_id
  sns_topic_arns     = [aws_sns_topic.slack_notification.arn]
}