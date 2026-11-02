use std::env;

use super::error::CliError;
use crate::echo;

const DEFAULT_TIMEOUT: u64 = 60000;
const DEFAULT_RECONNECT_INTERVAL: u64 = 0;
#[cfg(target_os = "windows")]
const DEFAULT_PIPE_NAME: &str = "\\\\.\\pipe\\duvet-nvim-ipc";
#[cfg(not(target_os = "windows"))]
const DEFAULT_PIPE_NAME: &str = "/tmp/duvet-nvim-ipc";

#[derive(Debug)]
pub struct Args {
    pub pipe_name: String,
    pub timeout: u64,
    pub reconnect_interval: u64,
    pub initial_reconnect: bool,
}

impl Args {
    pub fn parse() -> crate::Result<Args> {
        let args: Vec<String> = env::args().collect();

        let mut pipe_name = None;
        let mut timeout = None;
        let mut reconnect_interval = None;
        let mut initial_reconnect = false;

        let mut i = 1;
        while i < args.len() {
            match args[i].as_str() {
                "--version" | "-v" => {
                    echo!("{}", crate::cord::VERSION);
                    std::process::exit(0);
                }
                "--pipe-name" | "-p" => {
                    if i + 1 < args.len() {
                        pipe_name = Some(args[i + 1].clone());
                        i += 2;
                    } else {
                        return Err(CliError::Missing("--pipe-name").into());
                    }
                }
                "--timeout" | "-t" => {
                    if i + 1 < args.len() {
                        match args[i + 1].parse() {
                            Ok(t) => timeout = Some(t),
                            _ => {
                                return Err(CliError::Invalid(
                                    "--timeout",
                                    "timeout must be a valid u64",
                                )
                                .into());
                            }
                        }
                        i += 2;
                    }
                }
                "--reconnect-interval" | "-r" => {
                    if i + 1 < args.len() {
                        match args[i + 1].parse() {
                            Ok(t) => reconnect_interval = Some(t),
                            _ => {
                                return Err(CliError::Invalid(
                                    "--reconnect-interval",
                                    "reconnect interval must be a valid u64",
                                )
                                .into());
                            }
                        }
                        i += 2;
                    }
                }
                "--initial-reconnect" | "-i" => {
                    initial_reconnect = true;
                    i += 1;
                }
                other => {
                    return Err(CliError::Unknown(other.to_string()).into());
                }
            }
        }

        Ok(Args {
            pipe_name: pipe_name
                .unwrap_or_else(|| DEFAULT_PIPE_NAME.to_string()),
            timeout: timeout.unwrap_or(DEFAULT_TIMEOUT),
            reconnect_interval: reconnect_interval
                .unwrap_or(DEFAULT_RECONNECT_INTERVAL),
            initial_reconnect,
        })
    }
}
