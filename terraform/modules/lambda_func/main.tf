locals {
  # アセットが格納されているS3バケット名のデフォルト値
  # 環境に合わせて修正してください
  default_s3_bucket = "${var.stage}-lambda-deploy-rust-ts"

  # var.s3_bucketが指定されていればそれを使い、
  # 指定されていなければデフォルトの バケット名を使う
  s3_bucket = (
    var.s3_bucket != null ?
    var.s3_bucket :
    local.default_s3_bucket
  )

  # var.s3_key_prefixが指定されていればそれを使い、
  # 指定されていなければvar.function_nameを使う
  s3_key_prefix = (
    var.s3_key_prefix != null ?
    var.s3_key_prefix :
    var.function_name
  )

  # var.stageが指定されていれば関数名の先頭に付与する
  function_name = (
    var.stage != null ?
    "${var.stage}-${var.function_name}" :
    var.function_name
  )
}

data "aws_iam_policy_document" "assume_role_lambda" {
  # Lambda用信頼ポリシー
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  # Lambda実行ロール
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
  name               = "${local.function_name}-lambda-role"
}

data "aws_iam_policy" "lambda_basic_execution" {
  # 基本実行ポリシー
  name = "AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy" "lambda_vpc_access_execution" {
  # VPC接続用ポリシー
  name = "AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy" "managed_policies" {
  count = length(var.managed_policy_names)
  name  = var.managed_policy_names[count.index]
}

locals {
  # VPC有無で付与ポリシーを切り替え
  managed_policy_arn = (
    var.vpc_config == null ?
    [data.aws_iam_policy.lambda_basic_execution.arn] :
    [data.aws_iam_policy.lambda_vpc_access_execution.arn]
  )
}

resource "aws_iam_role_policy_attachments_exclusive" "managed_policies" {
  # マネージドポリシーをアタッチ
  policy_arns = concat(
    local.managed_policy_arn,
    [for policy in data.aws_iam_policy.managed_policies : policy.arn]
  )
  role_name = aws_iam_role.lambda_role.name
}

data "aws_iam_policy_document" "inline_policies" {
  # インラインポリシー定義
  count = length(var.iam_inline_policy_statements) > 0 ? 1 : 0
  dynamic "statement" {
    for_each = var.iam_inline_policy_statements
    content {
      actions   = statement.value.actions
      resources = statement.value.resources
      effect    = statement.value.effect
    }
  }
}

resource "aws_iam_role_policy" "inline_policies" {
  # インラインポリシーをアタッチ
  count  = length(var.iam_inline_policy_statements) > 0 ? 1 : 0
  name   = "${local.function_name}-inline-policy"
  role   = aws_iam_role.lambda_role.name
  policy = data.aws_iam_policy_document.inline_policies[0].json
}

data "aws_s3_object" "lambda_asset" {
  # S3上のLambdaアセット
  bucket        = local.s3_bucket
  key           = "${local.s3_key_prefix}/bootstrap.zip"
  checksum_mode = "ENABLED"
}

resource "aws_lambda_function" "this" {
  # Lambda関数本体
  function_name = local.function_name
  s3_bucket     = data.aws_s3_object.lambda_asset.bucket
  s3_key        = data.aws_s3_object.lambda_asset.key
  source_code_hash = data.aws_s3_object.lambda_asset.checksum_sha256
  handler       = var.handler
  runtime       = var.runtime
  role          = aws_iam_role.lambda_role.arn
  architectures = var.architectures
  timeout       = var.timeout
  memory_size   = var.memory_size
  environment {
    # 環境変数を設定
    variables = var.environment_variables
  }
  publish                        = var.publish
  layers                         = var.layers
  reserved_concurrent_executions = var.reserved_concurrent_executions
  dynamic "vpc_config" {
    # VPC設定がある場合のみ付与
    for_each = var.vpc_config == null ? [] : [1]
    content {
      subnet_ids         = var.vpc_config.subnet_ids
      security_group_ids = var.vpc_config.security_group_ids
    }
  }
  dynamic "dead_letter_config" {
    # 非同期実行時のデッドレターキューの設定がある場合のみ付与
    for_each = var.async_invocation_dlq_target_arn == null ? [] : [1]
    content {
      target_arn = var.async_invocation_dlq_target_arn
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  # CloudWatch Logsの保持期間を設定
  name = "/aws/lambda/${aws_lambda_function.this.function_name}"

  retention_in_days = var.log_group_retention_in_days
}

resource "aws_lambda_permission" "this" {
  # 外部サービスからのInvoke許可
  count = length(var.permissions)
  statement_id = "AllowExecutionFrom${title(
    split(".", var.permissions[count.index].principal)[0]
  )}"
  action        = var.permissions[count.index].action
  function_name = aws_lambda_function.this.function_name
  principal     = var.permissions[count.index].principal
  source_arn    = var.permissions[count.index].source_arn
}

data "aws_sns_topic" "alarm_action" {
  # アラーム通知先のSNSを参照
  count = length(var.error_alarm_sns_topic_names)
  name  = var.error_alarm_sns_topic_names[count.index]
}

resource "aws_cloudwatch_metric_alarm" "this" {
  # Lambdaエラー監視アラーム
  count               = length(var.error_alarm_sns_topic_names) > 0 ? 1 : 0
  alarm_name          = "${local.function_name}-error-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = var.error_alarm_threshold
  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }
  alarm_description  = "Alarm for ${aws_lambda_function.this.function_name} when errors occur"
  treat_missing_data = "notBreaching"
  actions_enabled    = true
  alarm_actions = [
    for topic in data.aws_sns_topic.alarm_action : topic.arn
  ]
}
