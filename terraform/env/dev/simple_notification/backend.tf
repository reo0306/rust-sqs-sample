terraform {
  backend "s3" {
    bucket = "dev-tfstate-aws-rust-lambda-book-project-ts"
    key    = "simple_notification/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
