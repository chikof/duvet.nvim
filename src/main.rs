#![deny(warnings)]
#![allow(mismatched_lifetime_syntaxes)]

mod cli;
mod cord;
mod error;
mod ipc;
mod messages;
mod presence;
mod protocol;
mod session;
mod types;
mod util;

use cli::args::Args;
use cord::{Config, Cord};
use error::Result;

fn main() -> Result<()> {
    let args = Args::parse()?;
    let config = Config::new(
        args.pipe_name,
        args.timeout,
        args.reconnect_interval,
        args.initial_reconnect,
        false,
    );
    let mut cord = Cord::new(config)?;

    cord.run()
}
