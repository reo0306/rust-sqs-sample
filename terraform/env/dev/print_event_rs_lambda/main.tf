locals {
  stage = "dev"
}

resource "aws_sqs_queue" "print_event_test" {
  name = "${local.stage}-print_event_test_rs"
}

module "print_event_rs_lambda" {
  source = "../../../modules/lambda_func"

  stage = local.stage
  function_name = "print_event_rs"
  runtime = "provided.al2023"
  handler = "bootstrap"
  timeout = 30
  iam_inline_policy_statements = [
    {
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
      action = "lambda:InvokeFunction"
      principal = "sqs.amazonaws.com"
    }
  ]
}

resource "aws_lambda_event_source_mapping" "print_event_sqs" {
  function_name = module.print_event_rs_lambda.lambda_function_name
  event_source_arn = aws_sqs_queue.print_event_test.arn
}

