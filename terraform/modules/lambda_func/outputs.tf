utput "lambda_function_name" {
  # 関数名
  value = aws_lambda_function.this.function_name
}
output "lambda_function_arn" {
  # 関数ARN
  value = aws_lambda_function.this.arn
}
output "lambda_function_published_version" {
  # 公開バージョン
  value = aws_lambda_function.this.version
}
output "lambda_function_invoke_arn" {
  # 呼び出しARN
  value = aws_lambda_function.this.invoke_arn
}
