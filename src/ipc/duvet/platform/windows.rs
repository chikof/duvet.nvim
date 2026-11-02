use std::ffi::OsStr;
use std::fs::File;
use std::os::windows::ffi::OsStrExt;
use std::os::windows::io::{AsRawHandle, FromRawHandle};
use std::sync::atomic::Ordering;
use std::sync::mpsc::Sender;
use std::{io, ptr};

use crate::ipc::bindings::{
    CreateEventW, CreateFileW, ERROR_IO_PENDING, FILE_FLAG_OVERLAPPED,
    GENERIC_READ, GENERIC_WRITE, GetLastError, GetOverlappedResult,
    INVALID_HANDLE_VALUE, OPEN_EXISTING, Overlapped, ReadFile, WriteFile,
};
use crate::ipc::duvet::client::{Connection, RichClient};
use crate::ipc::duvet::error::IpcError;
use crate::messages::events::local::ErrorEvent;
use crate::messages::events::server::StatusUpdateEvent;
use crate::messages::message::Message;
use crate::{debug, local_event, server_event, trace};

impl Connection for RichClient {
    /// Duvet's pipe is `\\.\pipe\duvet-ipc`.
    fn try_connect(&mut self, pipe_name: &str) -> crate::Result<bool> {
        trace!("Attempting to connect to Windows named pipe: {}", pipe_name);
        let wide_name: Vec<u16> =
            OsStr::new(pipe_name).encode_wide().chain(Some(0)).collect();

        unsafe {
            let handle = CreateFileW(
                wide_name.as_ptr(),
                GENERIC_READ | GENERIC_WRITE,
                0,
                ptr::null_mut(),
                OPEN_EXISTING,
                FILE_FLAG_OVERLAPPED,
                0 as _,
            );

            if handle == INVALID_HANDLE_VALUE {
                let error = io::Error::last_os_error();
                return match error.kind() {
                    io::ErrorKind::NotFound => {
                        trace!("Windows named pipe not found: {}", pipe_name);
                        Ok(false)
                    }
                    _ => {
                        debug!(
                            "Failed to connect to Windows named pipe: {}",
                            error
                        );
                        Ok(false)
                    }
                };
            }

            let pipe = File::from_raw_handle(handle);
            self.pipe = Some(pipe.into());
            debug!("Successfully connected to Windows named pipe");
            Ok(true)
        }
    }

    fn close(&mut self) {
        debug!("Closing Duvet Windows named pipe connection");
        self.pipe = None;
        let _ = self.thread_handle.take();
    }

    fn start_read_thread(&mut self, tx: Sender<Message>) -> crate::Result<()> {
        if let Some(pipe) = self.pipe.as_ref() {
            let pipe = pipe.clone();
            let is_ready = self.is_ready.clone();

            debug!("Starting Duvet IPC read thread (Windows)");
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

                let mut buf = [0u8; 8192];
                let handle = pipe.as_raw_handle();

                loop {
                    unsafe {
                        let h_event = CreateEventW(
                            ptr::null_mut(),
                            1,
                            0,
                            ptr::null_mut(),
                        );

                        let mut overlapped = Overlapped {
                            internal: 0,
                            internal_high: 0,
                            offset: 0,
                            offset_high: 0,
                            h_event,
                        };

                        let mut bytes_read = 0;
                        let read_result = ReadFile(
                            handle,
                            buf.as_mut_ptr(),
                            buf.len() as u32,
                            &mut bytes_read,
                            &mut overlapped,
                        );

                        if read_result == 0 {
                            let error = GetLastError();
                            if error != ERROR_IO_PENDING {
                                debug!(
                                    "Duvet IPC read failed with error code: {}",
                                    error
                                );
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

                        let mut bytes_transferred = 0;
                        if GetOverlappedResult(
                            handle,
                            &mut overlapped,
                            &mut bytes_transferred,
                            1,
                        ) == 0
                        {
                            debug!("Duvet IPC GetOverlappedResult failed");
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

                        trace!(
                            "Received {} bytes from Duvet IPC",
                            bytes_transferred
                        );
                    }
                }
            });

            self.thread_handle = Some(handle);
            Ok(())
        } else {
            debug!("Cannot start read thread: no pipe available");
            Err(IpcError::PipeNotFound.into())
        }
    }

    fn write(&self, payload: &[u8]) -> crate::Result<()> {
        self.pipe.as_ref().map_or(Ok(()), |pipe| {
            trace!("Writing {} bytes to Duvet IPC", payload.len());
            unsafe {
                let handle = pipe.as_raw_handle();
                let h_event =
                    CreateEventW(ptr::null_mut(), 1, 0, ptr::null_mut());

                let mut overlapped = Overlapped {
                    internal: 0,
                    internal_high: 0,
                    offset: 0,
                    offset_high: 0,
                    h_event,
                };

                let mut bytes_written = 0;
                let write_result = WriteFile(
                    handle,
                    payload.as_ptr(),
                    payload.len() as u32,
                    &mut bytes_written,
                    &mut overlapped,
                );

                if write_result == 0 {
                    let error = GetLastError();
                    if error != ERROR_IO_PENDING {
                        debug!(
                            "Duvet IPC write failed with error code: {}",
                            error
                        );
                        return Err(IpcError::ConnectionClosed.into());
                    }
                }

                let mut bytes_transferred = 0;
                if GetOverlappedResult(
                    handle,
                    &mut overlapped,
                    &mut bytes_transferred,
                    1,
                ) == 0
                {
                    debug!("Duvet IPC write GetOverlappedResult failed");
                    return Err(IpcError::ConnectionClosed.into());
                }

                trace!(
                    "Successfully wrote {} bytes to Duvet IPC",
                    bytes_transferred
                );
                Ok(())
            }
        })
    }
}
