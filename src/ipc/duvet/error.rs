use std::{fmt, io};

#[derive(Debug)]
pub enum IpcError {
    Io(io::Error),
    ConnectionClosed,
    PipeNotFound,
    Custom(String),
}

impl fmt::Display for IpcError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            IpcError::Io(err) => write!(f, "IO error: {}", err),
            IpcError::ConnectionClosed => {
                write!(f, "The connection was forcibly closed")
            }
            IpcError::PipeNotFound => {
                write!(f, "Duvet IPC pipe not found")
            }
            IpcError::Custom(msg) => write!(f, "{}", msg),
        }
    }
}

impl std::error::Error for IpcError {}

impl From<io::Error> for IpcError {
    fn from(err: io::Error) -> Self {
        IpcError::Io(err)
    }
}

impl From<&str> for IpcError {
    fn from(err: &str) -> Self {
        IpcError::Custom(err.to_string())
    }
}

impl From<String> for IpcError {
    fn from(err: String) -> Self {
        IpcError::Custom(err)
    }
}
