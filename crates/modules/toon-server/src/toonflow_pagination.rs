use serde::Serialize;

pub(crate) const fn default_page() -> i64 {
    1
}
pub(crate) const fn default_limit() -> i64 {
    20
}

#[derive(Debug, Serialize)]
pub struct PageData<T: Serialize> {
    pub data: Vec<T>,
    pub total: i64,
}

#[cfg(test)]
mod tests {
    use super::{default_limit, default_page};

    #[test]
    fn pagination_defaults_are_stable() {
        assert_eq!(default_page(), 1);
        assert_eq!(default_limit(), 20);
    }
}
