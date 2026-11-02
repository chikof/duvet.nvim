use std::io::{self, Read, Write};
use std::net::Shutdown;
use std::os::unix::net::UnixStream;
use std::sync::atomic::Ordering;
use std::sync::mpsc::Sender;

use crate::ipc::duvet::client::{Connection, RichClient};
use crate::ipc::duvet::error::IpcError;
use crate::messages::events::local::ErrorEvent;
use crate::messages::events::server::StatusUpdateEvent;
use crate::messages::message::Message;
use crate::{debug, local_event, server_event, trace};

impl Connection for RichClient {
    /// Duvet's socket is `duvet-ipc.sock` in the first non-empty of `XDG_RUNTIME_DIR`, `TMPDIR`,
    /// `TMP`, `TEMP`, else `/tmp`.
    fn try_connect(&mut self, pipe: &str) -> crate::Result<bool> {
        trace!("Attempting to connect to Unix socket: {}", pipe);
        match UnixStream::connect(pipe) {
            Ok(pipe) => {
                let read_pipe = pipe.try_clone().map_err(IpcError::Io)?;
                self.read_pipe = Some(read_pipe);
                self.write_pipe = Some(pipe);
                debug!("Successfully connected to Unix socket");
                Ok(true)
            }
            Err(e) => {
                debug!("Failed to connect to Unix socket {}: {}", pipe, e);
                Ok(false)
            }
        }
    }

    fn close(&mut self) {
        debug!("Closing Duvet Unix socket connection");
        if let Some(pipe) = self.read_pipe.take() {
            let _ = pipe.shutdown(Shutdown::Both);
        }
        if let Some(pipe) = self.write_pipe.take() {
            let _ = pipe.shutdown(Shutdown::Both);
        }
        let _ = self.thread_handle.take();
    }

    /// Duvet never writes, so a read only ends when it closes the connection.
    fn start_read_thread(&mut self, tx: Sender<Message>) -> crate::Result<()> {
        if let Some(mut read_pipe) = self.read_pipe.take() {
            let is_ready = self.is_ready.clone();

            debug!("Starting Duvet IPC read thread");
            let handle = std::thread::spawn(move || {
                if !is_ready.swap(true, Ordering::SeqCst) {
                    debug!("Duvet IPC connection is now ready");
                    tx.send(server_event!(
                        0,
                        StatusUpdate,
                        StatusUpdateEvent::ready()
                    ))
                    .ok();
                }

                let mut buf = [0u8; 256];
                loop {
                    match read_pipe.read(&mut buf) {
                        Ok(n) if n > 0 => continue,
                        result => {
                            debug!("Duvet IPC connection closed: {:?}", result);
                            tx.send(local_event!(
                                0,
                                Error,
                                ErrorEvent::new(Box::new(
                                    IpcError::ConnectionClosed
                                ))
                            ))
                            .ok();
                            break;
                        }
                    }
                }
            });

            self.thread_handle = Some(handle);
            Ok(())
        } else {
            debug!("Cannot start read thread: no read pipe available");
            Err(IpcError::PipeNotFound.into())
        }
    }

    fn write(&self, data: &[u8]) -> crate::Result<()> {
        self.write_pipe.as_ref().map_or(Ok(()), |mut pipe| {
            trace!("Writing {} bytes to Duvet IPC", data.len());
            pipe.write_all(data).map_err(|e: io::Error| {
                debug!("Failed to write to Duvet IPC: {}", e);
                IpcError::ConnectionClosed.into()
            })
        })
    }
}
