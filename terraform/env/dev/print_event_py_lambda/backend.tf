terraform {
  backend "s3" {
    bucket = "dev-tfstate-aws-rust-lambda-book-project-ts"
    key    = "print_event_py_lambda/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
