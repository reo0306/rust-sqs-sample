use crate::error::Error;
use crate::notifier::Notifer;

pub struct SNSSlackNotifier {
    client_sns: aws_sdk_sns::Client,
    sns_topic_arn: String,
}

impl SNSSlackNotifier {
    pub fn new(client_sns: aws_sdk_sns::Client, sns_topic_arn: String) -> Self {
        SNSSlackNotifer {
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
        let slack_payload = serde_json::json!({
            "version": "1.0",
            "source": "custom",
            "content": {
                "title": title,
                "description": description,
            }
        });
        let _resp = self
            .client_sns
            .publish()
            .message(slack_payload.to_string())
            .topic_arn(&self.sns_topic_arn)
            .send()
            .await?;
        Ok(())
    }
}

