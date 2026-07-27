use crossterm::event::KeyCode;
use ratatui::{
    layout::{Constraint, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{Block, Borders, Paragraph, Scrollbar, ScrollbarOrientation, ScrollbarState},
    Frame,
};
use tokio::sync::mpsc;

use crate::client::ConnectionState;
use crate::log_event::{group_lines, Event};
use crate::filter::Filter;

pub fn level_color(level: &Option<crate::parser::LogLevel>) -> Color {
    use crate::parser::LogLevel::*;
    match level {
        Some(Trace) => Color::Gray,
        Some(Debug) => Color::DarkGray,
        Some(Info) => Color::Cyan,
        Some(Warning) => Color::Yellow,
        Some(Error) => Color::Red,
        Some(Fatal) => Color::Magenta,
        None => Color::White,
    }
}

pub struct App {
    events: Vec<Event>,
    filter: Filter,
    scroll: usize,
    tail: bool,
    row_count: u16,
    #[allow(dead_code)]
    pub tx: mpsc::UnboundedSender<String>,
    cmd_tx: mpsc::UnboundedSender<String>,
}

impl App {
    pub fn new(
        tx: mpsc::UnboundedSender<String>,
        cmd_tx: mpsc::UnboundedSender<String>,
    ) -> Self {
        Self {
            events: Vec::new(),
            filter: Filter::new(),
            scroll: 0,
            tail: true,
            row_count: 0,
            tx,
            cmd_tx,
        }
    }

    pub fn push(&mut self, line: String) {
        let new_events = group_lines(vec![line]);
        self.events.extend(new_events);
        if self.tail {
            self.scroll = self.events.len().saturating_sub(1);
        }
    }

    pub fn push_separator(&mut self, timestamp: &str) {
        self.events.push(Event::separator(timestamp));
    }

    fn visible_events(&self) -> Vec<&Event> {
        self.events.iter().filter(|e| self.filter.matches(e)).collect()
    }

    fn scroll_up(&mut self, amount: usize) {
        self.tail = false;
        self.scroll = self.scroll.saturating_sub(amount);
    }

    fn scroll_down(&mut self, amount: usize) {
        let max = self.events.len().saturating_sub(1);
        self.scroll = (self.scroll + amount).min(max);
        if self.scroll >= max {
            self.tail = true;
        }
    }

    fn scroll_to(&mut self, pos: usize) {
        let max = self.events.len().saturating_sub(1);
        self.scroll = pos.min(max);
        if self.scroll >= max {
            self.tail = true;
        }
    }

    pub fn render(&mut self, frame: &mut Frame, state: &ConnectionState, url: &str) {
        let [filter_area, log_area, status_area] =
            Layout::vertical([Constraint::Length(1), Constraint::Min(1), Constraint::Length(1)])
                .areas::<3>(frame.area());

        self.render_filter(frame, filter_area);
        self.render_log(frame, log_area);
        self.render_status(frame, status_area, state, url);
    }

    fn render_filter(&mut self, frame: &mut Frame, area: Rect) {
        let indicator = self.filter.level_indicator();
        let text = format!(
            "[{}] /:{}",
            indicator,
            self.filter.raw()
        );
        let paragraph = Paragraph::new(text).block(Block::new().borders(Borders::NONE));
        frame.render_widget(paragraph, area);
    }

    fn render_log(&mut self, frame: &mut Frame, area: Rect) {
        let visible = self.visible_events();
        let total = visible.len();

        let start = if total == 0 {
            0
        } else {
            self.scroll.min(total.saturating_sub(1))
        };

        let area_height = area.height as usize;

        let mut items: Vec<Line> = Vec::new();

        if total > 0 {
            let lines_per_event: Vec<usize> = visible.iter().map(|e| e.lines.len()).collect();

            let mut display_start = start;
            let mut height_used = 0usize;
            for i in (0..=start).rev() {
                if height_used + lines_per_event[i] > area_height {
                    break;
                }
                height_used += lines_per_event[i];
                display_start = i;
            }

            for event in visible.iter().skip(display_start) {
                if items.len() >= area_height {
                    break;
                }
                let color = level_color(&event.level);
                for line in &event.lines {
                    let clean = crate::parser::strip_ansi(line);
                    items.push(Line::from(Span::styled(clean, Style::default().fg(color))));
                }
            }
        }

        self.row_count = items.len() as u16;

        let paragraph = Paragraph::new(Text::from(items))
            .block(Block::new().borders(Borders::NONE));
        frame.render_widget(paragraph, area);

        let mut scrollbar_state = ScrollbarState::new(total)
            .position(start);
        let scrollbar = Scrollbar::new(ScrollbarOrientation::VerticalRight)
            .begin_symbol(Some("↑"))
            .end_symbol(Some("↓"));
        frame.render_stateful_widget(scrollbar, area, &mut scrollbar_state);
    }

    fn render_status(
        &self,
        frame: &mut Frame,
        area: Rect,
        state: &ConnectionState,
        url: &str,
    ) {
        let state_str = match state {
            ConnectionState::Connected => "connected",
            ConnectionState::Disconnected => "disconnected",
            ConnectionState::Reconnecting => "reconnecting",
        };
        let state_color = match state {
            ConnectionState::Connected => Color::Green,
            ConnectionState::Disconnected => Color::Red,
            ConnectionState::Reconnecting => Color::Yellow,
        };

        let visible = self.visible_events().len();
        let total = self.events.len();

        let spans = vec![
            Span::styled(
                format!(" {} ", state_str),
                Style::default().fg(state_color).add_modifier(Modifier::BOLD),
            ),
            Span::styled(
                format!("| {} ", url),
                Style::default().fg(Color::White),
            ),
            Span::styled(
                format!("| {} events ", total),
                Style::default().fg(Color::White),
            ),
            Span::styled(
                format!("| Filter: {}/{} ", visible, total),
                Style::default().fg(Color::White),
            ),
        ];

        let paragraph = Paragraph::new(Line::from(spans));
        frame.render_widget(paragraph, area);
    }

    pub fn handle_key(&mut self, code: KeyCode) -> bool {
        match code {
            KeyCode::Char('q') => return false,
            KeyCode::Char('f') => self.tail = !self.tail,
            KeyCode::Char('/') => self.filter.set_pattern(""),
            KeyCode::Char('1') => self.filter.toggle_level(&crate::parser::LogLevel::Trace),
            KeyCode::Char('2') => self.filter.toggle_level(&crate::parser::LogLevel::Debug),
            KeyCode::Char('3') => self.filter.toggle_level(&crate::parser::LogLevel::Info),
            KeyCode::Char('4') => self.filter.toggle_level(&crate::parser::LogLevel::Warning),
            KeyCode::Char('5') => self.filter.toggle_level(&crate::parser::LogLevel::Error),
            KeyCode::Char('6') => self.filter.toggle_level(&crate::parser::LogLevel::Fatal),
            KeyCode::Enter => {
                let raw = self.filter.raw().to_string();
                if raw.starts_with('!') {
                    let _ = self.cmd_tx.send(raw);
                    self.filter.set_pattern("");
                } else {
                    self.filter.set_pattern("");
                }
            }
            KeyCode::Backspace => {
                let current = self.filter.raw().to_string();
                if !current.is_empty() {
                    self.filter
                        .set_pattern(&current[..current.len() - 1]);
                }
            }
            KeyCode::Up => self.scroll_up(1),
            KeyCode::Down => self.scroll_down(1),
            KeyCode::PageUp => self.scroll_up(10),
            KeyCode::PageDown => self.scroll_down(10),
            KeyCode::Home => self.scroll_to(0),
            KeyCode::End => {
                let max = self.events.len().saturating_sub(1);
                self.scroll_to(max);
            }
            _ => {}
        }
        true
    }

    pub fn handle_input(&mut self, ch: char) {
        let current = self.filter.raw().to_string();
        self.filter
            .set_pattern(&format!("{}{}", current, ch));
    }
}
