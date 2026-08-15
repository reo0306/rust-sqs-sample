locals {
  # デプロイ対象ステージ
  stage         = "dev"
}

resource "aws_sqs_queue" "print_event_test" {
  # テスト用SQSキュー
  name = "${local.stage}-print_event_test"
}

module "print_event_py_lambda" {
  # Lambda関数を子モジュールで記述
  source = "../../../modules/lambda_func"

  stage = local.stage
  function_name = "print_event_py"
  runtime = "python3.13"
  handler = "main.lambda_handler"
  timeout = 30
  iam_inline_policy_statements = [
    {
      # SQA受信に必要な権限
      actions = [
        "sqs:ReceiveMessage", 
        "sqs:DeleteMessage", 
        "sqs:GetQueueAttributes", 
      ]
      resources = [aws_sqs_queue.print_event_test.arn]
      effect = "Allow"
    }
  ]
  permissions = [
    {
      # SQSからのInvoke許可
      action = "lambda:InvokeFunction"
      principal = "sqs.amazonaws.com"
    }
  ]
}

resource "aws_lambda_event_source_mapping" "print_event_sqs" {
  function_name = module.print_event_py_lambda.lambda_function_name
  event_source_arn = aws_sqs_queue.print_event_test.arn
}

