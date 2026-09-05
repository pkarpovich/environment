use std::io::{BufRead, BufReader, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

const HEADERS: &str = "HTTP/1.1 200 OK\r\n\
Content-Type: text/event-stream\r\n\
Cache-Control: no-cache\r\n\
Connection: keep-alive\r\n\
Access-Control-Allow-Origin: *\r\n\
\r\n";

const GREET_TIMEOUT: Duration = Duration::from_secs(5);
const WRITE_TIMEOUT: Duration = Duration::from_secs(2);

#[derive(Clone)]
pub struct Broadcast {
    clients: Arc<Mutex<Vec<TcpStream>>>,
}

impl Broadcast {
    pub fn new() -> Self {
        Self {
            clients: Arc::new(Mutex::new(Vec::new())),
        }
    }

    pub fn serve(&self, listener: TcpListener) {
        let clients = Arc::clone(&self.clients);
        thread::spawn(move || {
            for incoming in listener.incoming() {
                let Ok(stream) = incoming else { continue };
                let clients = Arc::clone(&clients);
                thread::spawn(move || {
                    let Ok(()) = greet(&stream) else { return };
                    let Ok(mut guard) = clients.lock() else {
                        return;
                    };
                    guard.push(stream);
                });
            }
        });
    }

    pub fn send(&self, payload: &str) {
        let Ok(mut guard) = self.clients.lock() else {
            return;
        };

        let frame = format!("data: {payload}\n\n");
        let mut alive = Vec::new();
        for mut stream in guard.drain(..) {
            let Ok(()) = stream.write_all(frame.as_bytes()) else {
                continue;
            };
            let Ok(()) = stream.flush() else { continue };
            alive.push(stream);
        }
        *guard = alive;
    }
}

fn greet(stream: &TcpStream) -> std::io::Result<()> {
    stream.set_read_timeout(Some(GREET_TIMEOUT))?;

    let mut reader = BufReader::new(stream.try_clone()?);
    let mut line = String::new();
    loop {
        line.clear();
        let read = reader.read_line(&mut line)?;
        if read == 0 || line == "\r\n" || line == "\n" {
            break;
        }
    }

    stream.set_read_timeout(None)?;
    stream.set_write_timeout(Some(WRITE_TIMEOUT))?;

    let mut stream = stream.try_clone()?;
    stream.write_all(HEADERS.as_bytes())?;
    stream.flush()
}
