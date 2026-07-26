use std::time::Duration;

use mdns_sd::{ServiceDaemon, ServiceEvent};

pub struct DiscoveredDevice {
    pub ip: String,
    pub port: u16,
}

pub fn scan_devices(timeout_secs: u64) -> Vec<DiscoveredDevice> {
    let daemon = match ServiceDaemon::new() {
        Ok(d) => d,
        Err(_) => return vec![],
    };

    let service_type = "_diqit-log._tcp.local.";
    let receiver = match daemon.browse(service_type) {
        Ok(r) => r,
        Err(_) => return vec![],
    };

    let mut devices: Vec<DiscoveredDevice> = Vec::new();
    let deadline = std::time::Instant::now() + Duration::from_secs(timeout_secs);

    while std::time::Instant::now() < deadline {
        if let Ok(event) = receiver.recv_timeout(Duration::from_millis(500)) {
            match event {
                ServiceEvent::ServiceResolved(info) => {
                    if let Some(addr) = info.get_addresses().iter().next() {
                        let ip = addr.to_string();
                        let entry = DiscoveredDevice {
                            ip,
                            port: info.get_port(),
                        };
                        if !devices.iter().any(|d| d.ip == entry.ip && d.port == entry.port)
                        {
                            devices.push(entry);
                        }
                    }
                }
                _ => {}
            }
        }
    }

    let _ = daemon.shutdown();
    devices
}
