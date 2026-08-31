use lambda_runtime::{Error, LambdaEvent};
use serde::Deserialize;

/// This is a made-up example. Incoming messages come into the runtime as unicode
/// strings in json format, which can map to any structure that implements `serde::Deserialize`
/// The runtime pays no attention to the contents of the incoming message payload.
#[derive(Deserialize)]
pub(crate) struct IncomingMessage {
    title: String,
    description: String,
}

// テスト時のモック化を有効にする属性
// テストビルト時のみmockall:automockが適用される
#[cfg_attr(test, mockall::automock)]
trait Notifier {
    async fn notify(
        &self,
        title: String,
        description: String,
    ) -> Result<(), Error>;
}

// SNSを通じてSlackに通知を送信する構造体
struct SNSSlackNotifier {
    client_sns: aws_sdk_sns::Client,
    sns_topic_arn: String,
}

impl SNSSlackNotifier {
    fn new (client_sns: aws_sdk_sns::Client, sns_topic_arn: String) -> Self {
        SNSSlackNotifier {
            client_sns,
            sns_topic_arn,
        }
    }
}

impl Notifier for SNSSlackNotifier {
    async fn notify(
        &self,
        title: String,
        description: String,
    ) -> Result<(), Error> {
        // Amazon Q Developer用のSlack通知ペイロードを作成
        let slack_payload = serde_json::json!({
            "version": "1.0",
            "source": "custom",
            "content": {
                "title": title,
                "description": description
            }
        });
        // SNSトピックにメッセージを送信
        self.client_sns
            .publish()
            .message(slack_payload.to_string())
            .topic_arn(&self.sns_topic_arn)
            .send()
            .await?;
        Ok(())
    }
}

// グローバルなシングルトン - Lambda実行環境で再利用される
static SNS_SLACK_NOTIFIER: tokio::sync::OnceCell<SNSSlackNotifier> =
    tokio::sync::OnceCell::const_new();

// シングルトンインスタンスを取得する関数
async fn get_sns_slack_notifier() -> &'static SNSSlackNotifier {
    SNS_SLACK_NOTIFIER
        .get_or_init(|| async {
            // AWS設定をロード
            let config = aws_config::load_defaults(
                aws_config::BehaviorVersion::latest(),
            )
            .await;
            // 環境変数からSNSトピックARNを取得して、SNSSlackNotifierを作成
            SNSSlackNotifier::new(
                aws_sdk_sns::Client::new(&config),
                std::env::var("SNS_TOPIC_ARN")
                    .expect("Missing SNS_TOPIC_ARN env var"),
            )
        })
        .await
}

// メインのメインロジック - テスト可能な形式で分離
async fn main_handler<T: Notifier>(
    notifier: &T,
    title: String,
    description: String,
) -> Result <(), Error> {
    // 通知を実行
    notifier.notify(title, description).await
}

// Lambda実行時にコールされたハンドラ関数
pub(crate) async fn function_handler(
    event: LambdaEvent<IncomingMessage>,
) -> Result<(), Error> {
    // 入力イベントからパラメータ取得
    let title = event.payload.title;
    let description = event.payload.description;

    // シングルトンインスタンス取得
    let sns_slack_notifier = get_sns_slack_notifier().await;

    // メインロジックを呼び出し
    main_handler(sns_slack_notifier, title, description).await?;

    Ok(())
}

// テスト用のモジュール - テストビルド時にのみコンパイルされる
#[cfg(test)]
mod tests {
    use super::*;

    // メインロジック関数のユニットテスト
    #[tokio::test]
    async fn test_main_handler() {
        // モックのNotifierを作成
        let mut mock_notifier = MockNotifier::new();
        // notify()メソッドの期待値を設定
        mock_notifier
            .expect_notify()
            .withf(|title, description| {
                title == "Test Title" && description == "Test Description"
            })
            .times(1)
            .returning(|_, _| Ok(()));
        // メインロジックを実行
        let result = main_handler(
            &mock_notifier,
            "Test Title".to_string(),
            "Test Description".to_string(),
        )
        .await;
        // 実行結果が成功であることを検証
        assert!(result.is_ok());
    }
}
