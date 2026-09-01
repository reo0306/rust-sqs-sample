pub mod slack;

use crate::error::Error;

#[mockall::automock(target = Notifier)]
#[trait_variant::make(Notifier: Send)]
pub trait LocalNotifier {
    async fn notify(
        &self,
        title: String,
        description: String,
    ) -> Result<(), Error>;
}

