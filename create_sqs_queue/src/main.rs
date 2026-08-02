type Error = Box<dyn std::error::Error + Send + Sync + 'static>;

async fn create_queue(
    queue_name: &str,
    visibility_timeout: u32,
) -> Result<(), Error> {
    // 設定読み込み
    let config = aws_config::load_defaults(aws_config::BehaviorVersion::latest()).await;
    // SQSクライエント生成
    let client_sqs = aws_sdk_sqs::Client::new(&config);
    // CreateQueueのビルダを組み立て
    let builder = client_sqs
        .create_queue() // アクションを指定
        .queue_name(queue_name) // キュー名
        .attributes( // 属性追加
            aws_sdk_sqs::types::QueueAttributeName::VisibilityTimeout, // 属性名指定
            visibility_timeout.to_string(), // 属性値を文字列指定
        );
    // APIリクエスト送信
    builder.send().await?;
    Ok(())
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    // キュー名と可視性タイムアウト
    let queue_name = "my-queue";
    let visibility_timeout = 60;
    create_queue(queue_name, visibility_timeout).await?;
    println!("Queue created successfully");
    Ok(())
}
