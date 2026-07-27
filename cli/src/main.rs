mod client;
mod filter;
mod log_event;
mod parser;
mod scanner;
mod tui;

use std::io;
use std::time::Duration;

use clap::Parser;
use crossterm::event::{self, KeyCode, KeyEventKind};
use crossterm::{
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;
use tokio::sync::mpsc;

use crate::client::LogClient;
use crate::tui::App;

#[derive(Parser)]
#[command(name = "diqit-log")]
#[command(about = "TUI log viewer for diqit-logging WebSocket streams")]
struct Cli {
    /// Device IP address and optional port (e.g., 192.168.1.5 or 192.168.1.5:8080)
    /// If omitted, scans the local network for devices via mDNS.
    address: Option<String>,
}

fn select_device() -> Option<(String, u16)> {
    println!("Scanning for POS devices...");

    let devices = scanner::scan_devices(5);

    if devices.is_empty() {
        println!("No devices found.");
        print!("Enter IP address (or press Enter to quit): ");
        let mut input = String::new();
        io::stdin().read_line(&mut input).ok()?;
        let input = input.trim().to_string();
        if input.is_empty() {
            return None;
        }
        return Some(parse_address(&input));
    }

    println!();
    for (i, d) in devices.iter().enumerate() {
        println!("  {}. {}:{}", i + 1, d.ip, d.port);
    }

    loop {
        print!("Choose a device (1-{}) or enter IP (r=rescan, Enter=quit): ", devices.len());
        let mut input = String::new();
        io::stdin().read_line(&mut input).ok()?;
        let input = input.trim().to_string();

        if input.is_empty() {
            return None;
        }

        if input == "r" {
            return select_device();
        }

        if let Ok(idx) = input.parse::<usize>() {
            if idx >= 1 && idx <= devices.len() {
                let d = &devices[idx - 1];
                return Some((d.ip.clone(), d.port));
            }
        }

        // Treat as manual IP:port entry
        return Some(parse_address(&input));
    }
}

#[tokio::main]
async fn main() -> io::Result<()> {
    let cli = Cli::parse();

    let (host, port) = if let Some(ref addr) = cli.address {
        parse_address(addr)
    } else {
        match select_device() {
            Some((h, p)) => (h, p),
            None => {
                eprintln!("No device selected. Exiting.");
                return Ok(());
            }
        }
    };

    let (tx, mut rx) = mpsc::unbounded_channel::<String>();

    let url = format!("ws://{}:{}", host, port);

    let client = LogClient::new(&host, port);

    let tx_clone = tx.clone();
    tokio::spawn(async move {
        client.run(tx_clone).await;
    });

    // Terminal setup
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = App::new(tx);

    // Run the TUI loop
    let res = run_tui(&mut terminal, &mut app, &mut rx, &url).await;

    // Cleanup
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    if let Err(err) = res {
        eprintln!("Error: {:?}", err);
    }

    Ok(())
}

async fn run_tui<B: ratatui::backend::Backend>(
    terminal: &mut Terminal<B>,
    app: &mut App,
    rx: &mut mpsc::UnboundedReceiver<String>,
    url: &str,
) -> io::Result<()> {
    loop {
        terminal.draw(|frame| {
            app.render(frame, &client::ConnectionState::Connected, url);
        })?;

        tokio::select! {
            Some(line) = rx.recv() => {
                app.push(line);
            }
            _ = tokio::time::sleep(Duration::from_millis(50)) => {
                while event::poll(Duration::from_millis(0))? {
                    if let event::Event::Key(key) = event::read()? {
                        if key.kind == KeyEventKind::Press {
                            match key.code {
                                KeyCode::Char(ch) if ch != '/' && ch != 'q' => {
                                    app.handle_input(ch);
                                }
                                code => {
                                    if !app.handle_key(code) {
                                        return Ok(());
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

fn parse_address(address: &str) -> (String, u16) {
    if let Some((host, port_str)) = address.rsplit_once(':') {
        if let Ok(port) = port_str.parse::<u16>() {
            return (host.to_string(), port);
        }
    }
    (address.to_string(), 9229)
}
