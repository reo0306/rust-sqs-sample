terraform {
  backend "s3" {
    bucket = "dev-tfstate-aws-rust-lambda-book-project-ts"
    key    = "my_first_lambda_rs/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
