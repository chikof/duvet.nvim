use std::sync::Arc;
use std::sync::atomic::AtomicBool;
use std::sync::mpsc::Sender;
use std::thread::JoinHandle;

use crate::ipc::duvet::error::IpcError;
use crate::messages::events::server::status_update::Status;
use crate::messages::message::Message;
use crate::presence::packet::Packet;
use crate::protocol::json::Json;
use crate::{debug, trace};

/// Manages the connection to Duvet for sending and receiving data.
///
/// # Fields
/// * `pipe`: The communication pipe (platform-specific).
/// * `is_ready`: Indicates if the client is ready.
pub struct RichClient {
    pub pipe_paths: Vec<String>,
    #[cfg(target_os = "windows")]
    pub pipe: Option<Arc<std::fs::File>>,
    #[cfg(not(target_os = "windows"))]
    pub read_pipe: Option<std::os::unix::net::UnixStream>,
    #[cfg(not(target_os = "windows"))]
    pub write_pipe: Option<std::os::unix::net::UnixStream>,
    pub is_ready: Arc<AtomicBool>,
    pub thread_handle: Option<JoinHandle<()>>,
    pub is_reconnecting: bool,
    /// Managed externally.
    pub status: Status,
}

/// Defines methods for connecting and closing the client.
pub trait Connection {
    /// Connects to the given pipe.
    fn try_connect(&mut self, pipe: &str) -> crate::Result<bool>;
    /// Closes the connection to the pipe.
    fn close(&mut self);
    /// Start reading from the pipe in a separate thread.
    fn start_read_thread(&mut self, tx: Sender<Message>) -> crate::Result<()>;
    /// Write data to the pipe.
    fn write(&self, data: &[u8]) -> crate::Result<()>;
}

impl RichClient {
    pub fn new(pipe_paths: Vec<String>) -> Self {
        Self {
            pipe_paths,
            #[cfg(target_os = "windows")]
            pipe: None,
            #[cfg(not(target_os = "windows"))]
            read_pipe: None,
            #[cfg(not(target_os = "windows"))]
            write_pipe: None,
            is_ready: Arc::new(AtomicBool::new(false)),
            thread_handle: None,
            is_reconnecting: false,
            status: Status::Disconnected,
        }
    }

    /// Establishes a connection with Duvet.
    pub fn connect(&mut self) -> crate::Result<()> {
        debug!("Attempting to connect to Duvet IPC");
        if self.pipe_paths.is_empty() {
            for pipe in get_dirs() {
                trace!("Trying Duvet IPC pipe: {}", pipe);
                if self.try_connect(&pipe)? {
                    debug!("Connected to Duvet IPC pipe: {}", pipe);
                    return Ok(());
                }
            }
        } else {
            let pipes = std::mem::take(&mut self.pipe_paths);

            debug!("Custom pipe paths provided: {:#?}", pipes);

            for pipe in &pipes {
                trace!("Trying custom Duvet IPC pipe: {}", pipe);
                if self.try_connect(pipe)? {
                    debug!("Connected to custom Duvet IPC pipe: {}", pipe);
                    self.pipe_paths = pipes;
                    return Ok(());
                }
            }

            self.pipe_paths = pipes;
        }

        debug!("Failed to find Duvet IPC pipe");
        Err(IpcError::PipeNotFound.into())
    }

    /// Updates the client's rich presence.
    pub fn update(&self, packet: &Packet) -> crate::Result<()> {
        trace!("Updating Duvet rich presence");
        self.send(packet)
    }

    /// Clears the current rich presence.
    pub fn clear(&self) -> crate::Result<()> {
        debug!("Clearing Duvet rich presence");
        self.send(&Packet::Clear)
    }

    /// Writes one packet as a JSON line.
    fn send(&self, packet: &Packet) -> crate::Result<()> {
        let mut line = Json::serialize(packet)?;
        line.push('\n');

        match self.write(line.as_bytes()) {
            Err(_) => Err("The connection to Duvet was lost".into()),
            _ => Ok(()),
        }
    }
}

/// Where Duvet listens: a named pipe on Windows, else a socket in the user's runtime directory.
fn get_dirs() -> impl Iterator<Item = String> {
    #[cfg(target_os = "windows")]
    let path = r"\\.\pipe\duvet-ipc".to_string();
    #[cfg(not(target_os = "windows"))]
    let path = {
        let dir = ["XDG_RUNTIME_DIR", "TMPDIR", "TMP", "TEMP"]
            .iter()
            .find_map(|&var| std::env::var(var).ok().filter(|v| !v.is_empty()))
            .unwrap_or_else(|| "/tmp".to_string());
        format!("{}/duvet-ipc.sock", dir.trim_end_matches('/'))
    };
    std::iter::once(path)
}
