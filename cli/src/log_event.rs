use crate::parser::{LogLevel, is_new_event, parse_line};

#[derive(Debug, Clone)]
pub struct Event {
    pub level: Option<LogLevel>,
    pub lines: Vec<String>,
    pub raw_filter: String,
}

impl Event {
    pub fn new(level: Option<LogLevel>, lines: Vec<String>, raw_filter: String) -> Self {
        Self { level, lines, raw_filter }
    }

    pub fn separator(timestamp: &str) -> Self {
        Self {
            level: None,
            lines: vec![format!("--- Reconnected at {} ---", timestamp)],
            raw_filter: String::new(),
        }
    }
}

pub fn group_lines(raw_lines: Vec<String>) -> Vec<Event> {
    let mut events: Vec<Event> = Vec::new();

    for line in raw_lines {
        if is_new_event(&line) {
            let parsed = parse_line(line.clone());
            events.push(Event::new(parsed.level, vec![line.clone()], line));
        } else {
            let raw = line.clone();
            if let Some(last) = events.last_mut() {
                last.lines.push(line);
            } else {
                events.push(Event::new(None, vec![line], raw));
            }
        }
    }

    events
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_group_lines_emoji_detection() {
        let lines = vec![
            "ℹ [20:47:08.100] hello".to_string(),
            "                 data line".to_string(),
            "❗ [20:47:09.000] error".to_string(),
        ];

        let events = group_lines(lines);
        assert_eq!(events.len(), 2);
        assert_eq!(events[0].level, Some(LogLevel::Info));
        assert_eq!(events[0].lines.len(), 2);
        assert_eq!(events[1].level, Some(LogLevel::Error));
        assert_eq!(events[1].lines.len(), 1);
    }

    #[test]
    fn test_group_lines_no_emoji_starts_new() {
        let lines = vec![
            "                   orphan data".to_string(),
            "ℹ [20:47:08.100] real event".to_string(),
        ];

        let events = group_lines(lines);
        assert_eq!(events.len(), 2);
        assert!(events[0].level.is_none());
        assert_eq!(events[1].level, Some(LogLevel::Info));
    }

    #[test]
    fn test_separator_event() {
        let sep = Event::separator("20:47:08");
        assert!(sep.level.is_none());
        assert_eq!(sep.lines.len(), 1);
        assert!(sep.lines[0].contains("Reconnected"));
    }
}
