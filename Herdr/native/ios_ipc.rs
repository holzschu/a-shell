//! Embedded endpoints keep the original Unix stream protocol without sockaddr_un path limits.
//! Only this process can look up an endpoint; no filesystem or global CWD is used.
use crate::ipc::LocalStream;
use std::collections::HashMap;
use std::io;
use std::os::fd::OwnedFd;
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::sync::{
    atomic::{AtomicBool, AtomicU64, Ordering},
    mpsc, Mutex, OnceLock,
};
struct Endpoint {
    sender: mpsc::SyncSender<LocalStream>,
    generation: u64,
}
static NEXT: AtomicU64 = AtomicU64::new(1);
fn endpoints() -> &'static Mutex<HashMap<PathBuf, Endpoint>> {
    static E: OnceLock<Mutex<HashMap<PathBuf, Endpoint>>> = OnceLock::new();
    E.get_or_init(|| Mutex::new(HashMap::new()))
}
pub(crate) struct LocalListener {
    path: PathBuf,
    generation: u64,
    receiver: Mutex<mpsc::Receiver<LocalStream>>,
    nonblocking: AtomicBool,
}
impl LocalListener {
    pub(crate) fn set_nonblocking(
        &self,
        mode: interprocess::local_socket::ListenerNonblockingMode,
    ) -> io::Result<()> {
        self.nonblocking.store(
            !matches!(
                mode,
                interprocess::local_socket::ListenerNonblockingMode::Neither
            ),
            Ordering::Release,
        );
        Ok(())
    }
    pub(crate) fn accept(&self) -> io::Result<LocalStream> {
        let rx = self.receiver.lock().unwrap();
        if self.nonblocking.load(Ordering::Acquire) {
            rx.try_recv()
                .map_err(|_| io::Error::from(io::ErrorKind::WouldBlock))
        } else {
            rx.recv()
                .map_err(|_| io::Error::from(io::ErrorKind::BrokenPipe))
        }
    }
    pub(crate) fn incoming(&self) -> impl Iterator<Item = io::Result<LocalStream>> + '_ {
        std::iter::repeat_with(move || self.accept())
    }
}
impl Drop for LocalListener {
    fn drop(&mut self) {
        remove(&self.path, self.generation);
    }
}
pub(crate) fn bind(path: &Path) -> io::Result<LocalListener> {
    let mut e = endpoints().lock().unwrap();
    if e.contains_key(path) {
        return Err(io::Error::from(io::ErrorKind::AddrInUse));
    }
    let (sender, receiver) = mpsc::sync_channel(64);
    let generation = NEXT.fetch_add(1, Ordering::Relaxed);
    e.insert(path.to_owned(), Endpoint { sender, generation });
    Ok(LocalListener {
        path: path.to_owned(),
        generation,
        receiver: Mutex::new(receiver),
        nonblocking: AtomicBool::new(false),
    })
}
pub(crate) fn connect(path: &Path) -> io::Result<LocalStream> {
    let e = endpoints().lock().unwrap();
    let endpoint = e
        .get(path)
        .ok_or_else(|| io::Error::from(io::ErrorKind::NotFound))?;
    let (client, server) = UnixStream::pair()?;
    let wrap = |s: UnixStream| {
        LocalStream::UdSocket(interprocess::os::unix::uds_local_socket::Stream::from(
            OwnedFd::from(s),
        ))
    };
    endpoint
        .sender
        .try_send(wrap(server))
        .map_err(|_| io::Error::from(io::ErrorKind::WouldBlock))?;
    Ok(wrap(client))
}
pub(crate) fn identity(path: &Path) -> io::Result<u64> {
    endpoints()
        .lock()
        .unwrap()
        .get(path)
        .map(|e| e.generation)
        .ok_or_else(|| io::Error::from(io::ErrorKind::NotFound))
}
pub(crate) fn remove(path: &Path, generation: u64) {
    let mut e = endpoints().lock().unwrap();
    if e.get(path).is_some_and(|e| e.generation == generation) {
        e.remove(path);
    }
}
pub(crate) fn prepare(path: &Path) -> io::Result<()> {
    if endpoints().lock().unwrap().contains_key(path) {
        Err(io::Error::from(io::ErrorKind::AddrInUse))
    } else {
        Ok(())
    }
}
pub(crate) fn private(path: &Path, mode: u32) -> io::Result<()> {
    identity(path)?;
    if mode & 0o077 != 0 {
        return Err(io::Error::from(io::ErrorKind::PermissionDenied));
    }
    Ok(())
}
