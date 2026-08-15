locals {
  stage         = "dev"
  lambda_name   = "print_event_py"
  lambda_bucket = "${local.stage}-lambda-deploy-rust-ts"
}

resource "aws_sqs_queue" "print_event_test" {
  name = "${local.stage}-print_event_test"
}

data "aws_iam_policy_document" "assumed_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "lambda_basic_policy" {
  # Lambdaの基本実行ロール
  name = "AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "lambda_role" {
  # Lambdaの実行用IAMロール
  assume_role_policy = data.aws_iam_policy_document.assumed_role_policy.json
  name               = "${local.stage}-${local.lambda_name}-lambda-role"
}

resource "aws_iam_role_policy_attachments_exclusive" "lambda_role_policy" {
  # 基本ポリシーをアタッチ
  policy_arns = [
    data.aws_iam_policy.lambda_basic_policy.arn
  ]
  role_name = aws_iam_role.lambda_role.name
}

data "aws_iam_policy_document" "print_event_sqs" {
  # SQS受信に必要な情報
  statement {
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.print_event_test.arn]
    effect    = "Allow"
  }
}

resource "aws_iam_role_policy" "print_event_sqs" {
  # IAMロールにポリシーを付与
  policy = data.aws_iam_policy_document.print_event_sqs.json
  role   = aws_iam_role.lambda_role.id
  name   = "print_event_sqs_policy"
}

data "aws_s3_object" "lambda_asset" {
  bucket        = local.lambda_bucket
  key           = "${local.lambda_name}/bootstrap.zip"
  checksum_mode = "ENABLED"
}

resource "aws_lambda_function" "print_event" {
  # Lambda関数本体
  function_name = "${local.stage}-${local.lambda_name}"
  s3_bucket     = local.lambda_bucket
  s3_key        = "${local.lambda_name}/bootstrap.zip"
  source_code_hash = data.aws_s3_object.lambda_asset.checksum_sha256
  handler       = "main.lambda_handler"
  runtime       = "python3.13"
  architectures = ["arm64"]
  role          = aws_iam_role.lambda_role.arn
  timeout       = 30
}

resource "aws_cloudwatch_log_group" "print_event" {
  # ログ保持期間を明示 
  name = "/aws/lambda/${aws_lambda_function.print_event.function_name}"

  retention_in_days = 30
}

resource "aws_lambda_event_source_mapping" "print_event_sqs" {
  # SQSからLambda起動
  function_name    = aws_lambda_function.print_event.function_name
  event_source_arn = aws_sqs_queue.print_event_test.arn
}

resource "aws_lambda_permission" "print_event_to_sqs" {
  # SQSからのInvoke許可
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.print_event.function_name
  principal     = "sqs.amazonaws.com"
  statement_id  = "AllowExecutionFromSQS"
}

