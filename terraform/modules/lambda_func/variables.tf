variable "stage" {
  description = "環境のステージ"
  type        = string
  default     = null
}
variable "function_name" {
  description = "Lambda関数名"
  type        = string
}
variable "runtime" {
  description = "ランタイムの名前"
  type        = string
}
variable "handler" {
  description = "ハンドラ"
  type        = string
}
variable "architectures" {
  description = "Lambda関数のアーキテクチャ"
  type        = list(string)
  default     = ["arm64"]
}
variable "timeout" {
  description = "Lambda関数の実行タイムアウト時間（秒）"
  type        = number
  default     = 3
}
variable "memory_size" {
  description = "Lambda関数が使用可能なメモリサイズ（MB）"
  type        = number
  default     = 128
}
variable "s3_bucket" {
  description = "Lambda関数のアセットが格納されているS3バケット名"
  type        = string
  default     = null
}
variable "s3_key_prefix" {
  description = "Lambda関数のアセットのS3キープレフィックス"
  type        = string
  default     = null
}
variable "managed_policy_names" {
  description = "Lambda関数にアタッチするAWSマネージドポリシーのリスト"
  type        = list(string)
  default     = []
}
variable "iam_inline_policy_statements" {
  description = "Lambda関数にアタッチするインラインIAMポリシーステートメントの リスト"
  type = list(object({
    actions   = list(string)
    resources = list(string)
    effect    = string
  }))
  default = []
}
variable "environment_variables" {
  description = "Lambda関数に設定する環境変数のマップ"
  type        = map(string)
  default     = {}
}
variable "permissions" {
  description = "Lambda関数に付与する実行権限のリスト"
  type = list(object({
    action     = string
    principal  = string
    source_arn = optional(string)
  }))
  default = []
}
variable "log_group_retention_in_days" {
  description = "CloudWatch Logsでログイベントを保持する日数"
  type        = number
  default     = 30
}
variable "publish" {
  description = "更新時にLambda関数の新しいバージョンを公開するかどうか"
  type        = bool
  default     = false
}
variable "layers" {
  description = "Lambda関数にアタッチするLambdaレイヤーARNのリスト"
  type        = list(string)
  default     = []
}
variable "reserved_concurrent_executions" {
  description = "Lambda関数の予約同時実行数"
  type        = number
  default     = null
}
variable "error_alarm_sns_topic_names" {
  description = "アラーム通知に使用するSNSトピック名のリスト"
  type        = list(string)
  default     = []
}
variable "error_alarm_threshold" {
  description = "エラーアラームのしきい値"
  type        = number
  default     = 1
}
variable "vpc_config" {
  description = "Lambda関数のVPC設定"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}
variable "async_invocation_dlq_target_arn" {
  description = "非同期実行失敗時のデッドレターキューのARN(SQSキューまたはSNSトピック)"
  type        = string
  default     = null
}
