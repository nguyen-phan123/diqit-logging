#[derive(Debug, Clone, PartialEq)]
pub enum LogLevel {
    Trace,
    Debug,
    Info,
    Warning,
    Error,
    Fatal,
}

#[derive(Debug, Clone)]
pub struct LogEvent {
    pub level: Option<LogLevel>,
    pub lines: Vec<String>,
    pub raw: String,
}

pub fn strip_ansi(line: &str) -> String {
    let mut result = String::with_capacity(line.len());
    let mut chars = line.chars().peekable();

    while let Some(&c) = chars.peek() {
        if c == '\x1b' {
            chars.next(); // skip ESC
            chars.next(); // skip '['
            while let Some(&d) = chars.peek() {
                chars.next();
                if d == 'm' {
                    break;
                }
            }
        } else {
            result.push(chars.next().unwrap());
        }
    }

    result
}

pub fn detect_level(first_char: char) -> Option<LogLevel> {
    match first_char {
        '▫' => Some(LogLevel::Trace),
        '▪' => Some(LogLevel::Debug),
        'ℹ' => Some(LogLevel::Info),
        '⚡' => Some(LogLevel::Warning),
        '❗' => Some(LogLevel::Error),
        '💀' => Some(LogLevel::Fatal),
        _ => None,
    }
}

const EMOJI_CHARS: [char; 6] = ['▫', '▪', 'ℹ', '⚡', '❗', '💀'];

pub fn is_new_event(line: &str) -> bool {
    let cleaned = strip_ansi(line);
    cleaned.chars().next().map_or(false, |c| EMOJI_CHARS.contains(&c))
}

pub fn parse_line(line: String) -> LogEvent {
    let raw = line.clone();
    let cleaned = strip_ansi(&line);
    let level = cleaned.chars().next().and_then(detect_level);
    let lines = vec![line];

    LogEvent { level, lines, raw }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_strip_ansi_basic() {
        let input = "ℹ \x1b[38;5;240m[20:47:08.100]\x1b[0m hello";
        let output = strip_ansi(input);
        assert_eq!(output, "ℹ [20:47:08.100] hello");
    }

    #[test]
    fn test_strip_ansi_no_escape() {
        let input = "❓ plain text no codes";
        let output = strip_ansi(input);
        assert_eq!(output, input);
    }

    #[test]
    fn test_detect_level_info() {
        assert_eq!(detect_level('ℹ'), Some(LogLevel::Info));
    }

    #[test]
    fn test_detect_level_warning() {
        assert_eq!(detect_level('⚡'), Some(LogLevel::Warning));
    }

    #[test]
    fn test_detect_level_error() {
        assert_eq!(detect_level('❗'), Some(LogLevel::Error));
    }

    #[test]
    fn test_detect_level_debug() {
        assert_eq!(detect_level('▪'), Some(LogLevel::Debug));
    }

    #[test]
    fn test_detect_level_trace() {
        assert_eq!(detect_level('▫'), Some(LogLevel::Trace));
    }

    #[test]
    fn test_detect_level_fatal() {
        assert_eq!(detect_level('💀'), Some(LogLevel::Fatal));
    }

    #[test]
    fn test_detect_level_none() {
        assert_eq!(detect_level('A'), None);
        assert_eq!(detect_level(' '), None);
    }

    #[test]
    fn test_is_new_event_with_emoji() {
        assert!(is_new_event("ℹ [20:47:08.100] hello world"));
        assert!(is_new_event("▪ [20:47:08.100] debug msg"));
        assert!(is_new_event("❗ [20:47:08.100] error!"));
    }

    #[test]
    fn test_is_new_event_with_ansi_prefix() {
        assert!(is_new_event("ℹ \x1b[38;5;240m[20:47:08.100]\x1b[0m hello"));
        assert!(is_new_event("\x1b[38;5;12mℹ \x1b[38;5;240m[20:47:08.100]\x1b[0m hello"));
    }

    #[test]
    fn test_is_new_event_continuation() {
        assert!(!is_new_event("                 dim data line"));
    }

    #[test]
    fn test_parse_line_extracts_level() {
        let event = parse_line("ℹ [20:47:08.100] hello".to_string());
        assert_eq!(event.level, Some(LogLevel::Info));
        assert_eq!(event.lines.len(), 1);
    }

    #[test]
    fn test_parse_line_no_level() {
        let event = parse_line("                 some data".to_string());
        assert!(event.level.is_none());
    }
}
