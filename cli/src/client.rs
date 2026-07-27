use std::time::Duration;

use futures_util::{SinkExt, StreamExt};
use tokio::time::sleep;
use tokio_tungstenite::connect_async;
use tokio_tungstenite::tungstenite::Message;

#[derive(Debug, Clone, PartialEq)]
pub enum ConnectionState {
    Connected,
    Disconnected,
    Reconnecting,
}

pub struct LogClient {
    url: String,
    state: ConnectionState,
    buffer: Vec<String>,
}

impl LogClient {
    pub fn new(host: &str, port: u16) -> Self {
        let url = format!("ws://{}:{}", host, port);
        Self {
            url,
            state: ConnectionState::Disconnected,
            buffer: Vec::new(),
        }
    }

    pub fn state(&self) -> &ConnectionState {
        &self.state
    }

    pub fn url(&self) -> &str {
        &self.url
    }

    pub fn drain_buffer(&mut self) -> Vec<String> {
        std::mem::take(&mut self.buffer)
    }

    pub async fn run(
        mut self,
        tx: tokio::sync::mpsc::UnboundedSender<String>,
        mut cmd_rx: tokio::sync::mpsc::UnboundedReceiver<String>,
    ) {
        loop {
            self.state = ConnectionState::Reconnecting;

            match connect_async(&self.url).await {
                Ok((ws, _)) => {
                    self.state = ConnectionState::Connected;
                    let (mut write, mut read) = ws.split();

                    loop {
                        tokio::select! {
                            msg = read.next() => {
                                match msg {
                                    Some(Ok(Message::Text(text))) => {
                                        self.buffer.push(text.clone());
                                        let _ = tx.send(text);
                                    }
                                    Some(Ok(Message::Close(_))) | None => {
                                        self.state = ConnectionState::Disconnected;
                                        let _ = tx.send("--- Disconnected ---".into());
                                        break;
                                    }
                                    Some(Err(e)) => {
                                        self.state = ConnectionState::Disconnected;
                                        let _ = tx.send(format!("--- Error: {} ---", e));
                                        break;
                                    }
                                    _ => {}
                                }
                            }
                            cmd = cmd_rx.recv() => {
                                match cmd {
                                    Some(text) => {
                                        let _ = write.send(Message::Text(text.into())).await;
                                    }
                                    None => {
                                        let _ = write.close().await;
                                        return;
                                    }
                                }
                            }
                            _ = tx.closed() => {
                                let _ = write.close().await;
                                return;
                            }
                        }
                    }
                }
                Err(e) => {
                    self.state = ConnectionState::Disconnected;
                    let _ = tx.send(format!("--- Connect failed: {} ---", e));
                }
            }

            sleep(Duration::from_secs(2)).await;
        }
    }
}
