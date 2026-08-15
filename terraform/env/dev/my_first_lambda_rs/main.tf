locals {
  stage = "dev"
}

module "my_first_lambda" {
  source = "../../../modules/lambda_func"
  stage = local.stage
  function_name = "MyFirstLambda"
  runtime = "provided.al2023"
  handler = "bootstrap"
  timeout = 30
}

