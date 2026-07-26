    use crate::log_event::Event;
use crate::parser::LogLevel;
use regex::Regex;

#[derive(Debug)]
pub struct Filter {
    re: Option<Regex>,
    raw: String,
    pub enabled_levels: [bool; 6],
}

impl Filter {
    pub fn new() -> Self {
        Self {
            re: None,
            raw: String::new(),
            enabled_levels: [true; 6],
        }
    }

    pub fn set_pattern(&mut self, pattern: &str) {
        self.raw = pattern.to_string();
        self.re = if pattern.is_empty() {
            None
        } else {
            Regex::new(pattern).ok()
        };
    }

    pub fn toggle_level(&mut self, level: &LogLevel) {
        let idx = level_to_idx(level);
        self.enabled_levels[idx] = !self.enabled_levels[idx];
    }

    pub fn matches(&self, event: &Event) -> bool {
        if let Some(ref level) = event.level {
            if !self.enabled_levels[level_to_idx(level)] {
                return false;
            }
        }

        if let Some(ref re) = self.re {
            re.is_match(&event.raw_filter)
        } else {
            true
        }
    }

    pub fn raw(&self) -> &str {
        &self.raw
    }

    pub fn level_indicator(&self) -> String {
        let chars = ['T', 'D', 'I', 'W', 'E', 'F'];
        let mut s = String::new();
        for (i, &c) in chars.iter().enumerate() {
            if self.enabled_levels[i] {
                s.push(c);
            } else {
                s.push('·');
            }
        }
        s
    }
}

fn level_to_idx(level: &LogLevel) -> usize {
    match level {
        LogLevel::Trace => 0,
        LogLevel::Debug => 1,
        LogLevel::Info => 2,
        LogLevel::Warning => 3,
        LogLevel::Error => 4,
        LogLevel::Fatal => 5,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
use crate::log_event::Event;

    #[test]
    fn test_filter_empty_matches_all() {
        let filter = Filter::new();
        let event = Event::new(Some(LogLevel::Info), vec!["hello".into()], "hello".into());
        assert!(filter.matches(&event));
    }

    #[test]
    fn test_filter_level_off() {
        let mut filter = Filter::new();
        filter.toggle_level(&LogLevel::Info);
        let event = Event::new(Some(LogLevel::Info), vec!["hello".into()], "hello".into());
        assert!(!filter.matches(&event));
    }

    #[test]
    fn test_filter_regex_match() {
        let mut filter = Filter::new();
        filter.set_pattern("error|fail");
        let event = Event::new(None, vec!["error: something".into()], "error: something".into());
        assert!(filter.matches(&event));
    }

    #[test]
    fn test_filter_regex_no_match() {
        let mut filter = Filter::new();
        filter.set_pattern("error");
        let event = Event::new(None, vec!["hello".into()], "hello".into());
        assert!(!filter.matches(&event));
    }
}
