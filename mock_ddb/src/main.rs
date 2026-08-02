type Error = Box<dyn std::error::Error + Send + Sync + 'static>;

#[cfg_attr(test, mockall::automock)]
trait DynamoDBOperator {
    // テーブル状態取得
    async fn get_table_status(
        &self,
        table_name: String,
    ) -> Result<String, Error>;
}

struct DynamoDBImpl {
    client: aws_sdk_dynamodb::Client,
}

impl DynamoDBImpl {
    fn new(client: aws_sdk_dynamodb::Client) -> Self {
        Self { client }
    }
}

impl DynamoDBOperator for DynamoDBImpl {
    async fn get_table_status(
        &self,
        table_name: String,
    ) -> Result<String, Error> {
        // describe_tableでステータス取得
        let output = self
            .client
            .describe_table()
            .table_name(table_name)
            .send()
            .await?;
        let status = output
            .table
            .and_then(|table| table.table_status)
            .and_then(|status| Some(status.as_str().to_string()))
            .unwrap_or_default();
        Ok(status)
    }
}

async fn main_handler<T: DynamoDBOperator>(
    dynamodb_operator: &T,
    table_name: String,
) -> Result<String, Error> {
    let output = dynamodb_operator.get_table_status(table_name).await;
    output.and_then(|status| {
        if status == "ACTIVE" {
            Ok("OK".to_string())
        } else {
            Ok("NG".to_string())
        }
    })
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    // SDK設定とクライアント生成
    let config = aws_config::load_defaults(aws_config::BehaviorVersion::latest()).await;
    let client = aws_sdk_dynamodb::Client::new(&config);
    let dynamodb_operator = DynamoDBImpl::new(client);
    let table_name = "".to_string();
    // メイン処理実行
    let result = main_handler(&dynamodb_operator, table_name).await?;
    println!("Result: {}", result);
    Ok(())
}

#[cfg(test)]
mod test {
    use super::*;
    use mockall::predicate::eq;

    #[tokio::test]
    async fn test_main_handler_active() {
        let mut mock = MockDynamoDBOperator::new();
        mock.expect_get_table_status()
            .with(eq("test-table".to_string()))
            .returning(|_| Ok("ACTIVE".to_string()));

        let result = main_handler(&mock, "test-table".to_string()).await.unwrap();
        assert_eq!(result, "OK");
    }

    #[tokio::test]
    async fn test_main_handler_other() {
        let mut mock = MockDynamoDBOperator::new();
        mock.expect_get_table_status()
            .with(eq("test-table".to_string()))
            .returning(|_| Ok("CREATING".to_string()));
        
        let result = main_handler(&mock, "test-table".to_string()).await.unwrap();
        assert_eq!(result, "NG");
    }

    #[tokio::test]
    async fn test_main_handler_error() {
        let mut mock = MockDynamoDBOperator::new();
        mock.expect_get_table_status()
            .with(eq("test-table".to_string()))
            .returning(|_| Err("Some error".into()));
        
        let result = main_handler(&mock, "test-table".to_string()).await;
        assert!(result.is_err());
    }
}