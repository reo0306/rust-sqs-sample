use lambda_runtime::{Error, LambdaEvent};
use serde_json::Value;

pub(crate) async fn function_handler(
    event: LambdaEvent<Value>,
) -> Result<(), Error> {
    println!("{}", event.payload);
    Ok(())
}

