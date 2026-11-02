use super::activity::Activity;
use crate::protocol::json;

pub enum Packet<'a> {
    Set(&'a Activity),
    Clear,
}

impl json::Serialize for Packet<'_> {
    fn serialize<'a>(
        &'a self,
        f: json::SerializeFn<'a>,
        state: &mut json::SerializeState,
    ) -> crate::Result<()> {
        match self {
            Packet::Set(activity) => {
                f("type", json::ValueRef::String("SET_ACTIVITY"), state)?;
                f("data", json::ValueRef::Object(*activity), state)?;
            }
            Packet::Clear => {
                f("type", json::ValueRef::String("CLEAR_ACTIVITY"), state)?;
            }
        }

        Ok(())
    }
}
