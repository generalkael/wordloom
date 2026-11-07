//! Corkboard layouts.
//!
//! Every folder's corkboard is a grid of its children in binder order by
//! default. A board can instead be *freeform*: cards sit wherever the user
//! drops them, without changing the binder (the view can reorder the
//! binder to match). A board can also hold *notes*,
//! sticky cards that live only on that board and are not binder items. The
//! project has one corkboard colour.

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::model::NodeId;
use crate::{Error, Result};

/// The colours a note can have, by name (the UI picks the shade).
pub const NOTE_COLORS: &[&str] = &["yellow", "pink", "blue", "green", "white"];

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct BoardNote {
    pub id: Uuid,
    #[serde(default)]
    pub title: String,
    #[serde(default)]
    pub text: String,
    /// One of [`NOTE_COLORS`].
    #[serde(default = "default_note_color")]
    pub color: String,
    /// Board units (pixels at the standard card size), origin top-left.
    #[serde(default)]
    pub x: f64,
    #[serde(default)]
    pub y: f64,
}

fn default_note_color() -> String {
    NOTE_COLORS[0].to_string()
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
pub struct Board {
    /// Cards placed by hand instead of in a grid.
    #[serde(default)]
    pub freeform: bool,
    /// Where each binder card sits on the freeform board (board units).
    /// Cards without a place are laid out in free grid slots.
    #[serde(default)]
    pub positions: BTreeMap<NodeId, [f64; 2]>,
    #[serde(default)]
    pub notes: Vec<BoardNote>,
}

impl Board {
    fn is_empty(&self) -> bool {
        !self.freeform && self.positions.is_empty() && self.notes.is_empty()
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
pub struct Boards {
    /// `#rrggbb`, or None for the theme's cork colour.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub color: Option<String>,
    /// Keyed by the folder whose children the board shows.
    #[serde(default)]
    pub boards: BTreeMap<NodeId, Board>,
}

fn valid_point(x: f64, y: f64) -> Result<(f64, f64)> {
    if x.is_finite() && y.is_finite() {
        // Nothing above or left of the board's corner.
        Ok((x.max(0.0), y.max(0.0)))
    } else {
        Err(Error::Invalid("not a position on the board".into()))
    }
}

/// Accepts `#rgb` or `#rrggbb` (any case); returns `#rrggbb` in lower case.
pub fn normalize_color(c: &str) -> Option<String> {
    let hex = c.trim().strip_prefix('#')?;
    if !hex.chars().all(|ch| ch.is_ascii_hexdigit()) {
        return None;
    }
    match hex.len() {
        6 => Some(format!("#{}", hex.to_ascii_lowercase())),
        3 => Some(format!(
            "#{}",
            hex.chars()
                .flat_map(|ch| [ch, ch])
                .collect::<String>()
                .to_ascii_lowercase()
        )),
        _ => None,
    }
}

impl Boards {
    pub fn board(&self, container: NodeId) -> Option<&Board> {
        self.boards.get(&container)
    }

    fn board_mut(&mut self, container: NodeId) -> &mut Board {
        self.boards.entry(container).or_default()
    }

    /// Drop boards that hold nothing, so project.json stays tidy.
    fn prune(&mut self, container: NodeId) {
        if self.boards.get(&container).is_some_and(Board::is_empty) {
            self.boards.remove(&container);
        }
    }

    /// "" goes back to the theme's colour.
    pub fn set_color(&mut self, color: &str) -> Result<()> {
        self.color = if color.trim().is_empty() {
            None
        } else {
            Some(
                normalize_color(color)
                    .ok_or_else(|| Error::Invalid(format!("not a colour: {color}")))?,
            )
        };
        Ok(())
    }

    pub fn set_freeform(&mut self, container: NodeId, on: bool) {
        self.board_mut(container).freeform = on;
        self.prune(container);
    }

    pub fn place(&mut self, container: NodeId, card: NodeId, x: f64, y: f64) -> Result<()> {
        let (x, y) = valid_point(x, y)?;
        self.board_mut(container).positions.insert(card, [x, y]);
        Ok(())
    }

    /// Forget where the cards were put (they go back to grid slots).
    /// Notes keep their places.
    pub fn tidy(&mut self, container: NodeId) {
        self.board_mut(container).positions.clear();
        self.prune(container);
    }

    pub fn add_note(&mut self, container: NodeId, x: f64, y: f64, text: &str) -> Result<Uuid> {
        let (x, y) = valid_point(x, y)?;
        let id = Uuid::new_v4();
        self.board_mut(container).notes.push(BoardNote {
            id,
            title: String::new(),
            text: text.to_string(),
            color: default_note_color(),
            x,
            y,
        });
        Ok(id)
    }

    fn note_mut(&mut self, container: NodeId, note: Uuid) -> Result<&mut BoardNote> {
        self.boards
            .get_mut(&container)
            .and_then(|b| b.notes.iter_mut().find(|n| n.id == note))
            .ok_or_else(|| Error::Invalid("no such note on this board".into()))
    }

    pub fn update_note(
        &mut self,
        container: NodeId,
        note: Uuid,
        title: &str,
        text: &str,
    ) -> Result<()> {
        let n = self.note_mut(container, note)?;
        n.title = title.trim().to_string();
        n.text = text.to_string();
        Ok(())
    }

    pub fn color_note(&mut self, container: NodeId, note: Uuid, color: &str) -> Result<()> {
        if !NOTE_COLORS.contains(&color) {
            return Err(Error::Invalid(format!("not a note colour: {color}")));
        }
        self.note_mut(container, note)?.color = color.to_string();
        Ok(())
    }

    pub fn move_note(&mut self, container: NodeId, note: Uuid, x: f64, y: f64) -> Result<()> {
        let (x, y) = valid_point(x, y)?;
        let n = self.note_mut(container, note)?;
        n.x = x;
        n.y = y;
        Ok(())
    }

    /// Takes the note off the board and returns it.
    pub fn remove_note(&mut self, container: NodeId, note: Uuid) -> Result<BoardNote> {
        let b = self
            .boards
            .get_mut(&container)
            .ok_or_else(|| Error::Invalid("no such note on this board".into()))?;
        let i = b
            .notes
            .iter()
            .position(|n| n.id == note)
            .ok_or_else(|| Error::Invalid("no such note on this board".into()))?;
        let n = b.notes.remove(i);
        self.prune(container);
        Ok(n)
    }

    /// Drop everything about an item that has been deleted for good: its
    /// own board (and the notes on it) and its place on other boards.
    pub fn forget_node(&mut self, node: NodeId) {
        self.boards.remove(&node);
        for b in self.boards.values_mut() {
            b.positions.remove(&node);
        }
        self.boards.retain(|_, b| !b.is_empty());
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn colours_are_normalized() {
        assert_eq!(normalize_color("#ABC").as_deref(), Some("#aabbcc"));
        assert_eq!(normalize_color(" #12Ab9f ").as_deref(), Some("#12ab9f"));
        assert!(normalize_color("red").is_none());
        assert!(normalize_color("#12345").is_none());
        let mut b = Boards::default();
        b.set_color("#C9A97C").unwrap();
        assert_eq!(b.color.as_deref(), Some("#c9a97c"));
        assert!(b.set_color("blue").is_err());
        b.set_color("").unwrap();
        assert!(b.color.is_none());
    }

    #[test]
    fn places_notes_and_pruning() {
        let (board, card) = (Uuid::new_v4(), Uuid::new_v4());
        let mut b = Boards::default();
        b.set_freeform(board, true);
        b.place(board, card, 40.0, -5.0).unwrap();
        assert_eq!(b.board(board).unwrap().positions[&card], [40.0, 0.0]);
        assert!(b.place(board, card, f64::NAN, 0.0).is_err());
        let n = b.add_note(board, 10.0, 20.0, "Idea").unwrap();
        b.update_note(board, n, " Title ", "Body").unwrap();
        b.color_note(board, n, "pink").unwrap();
        assert!(b.color_note(board, n, "purple").is_err());
        b.move_note(board, n, 70.0, 80.0).unwrap();
        let note = &b.board(board).unwrap().notes[0];
        assert_eq!(
            (note.title.as_str(), note.text.as_str(), note.color.as_str()),
            ("Title", "Body", "pink")
        );
        assert_eq!((note.x, note.y), (70.0, 80.0));
        b.tidy(board);
        assert!(b.board(board).unwrap().positions.is_empty());
        assert_eq!(b.board(board).unwrap().notes.len(), 1);
        assert_eq!(b.remove_note(board, n).unwrap().title, "Title");
        assert!(b.remove_note(board, n).is_err());
        b.set_freeform(board, false);
        assert!(b.boards.is_empty(), "an empty grid board is dropped");
    }

    #[test]
    fn forgetting_a_node() {
        let (outer, inner, card) = (Uuid::new_v4(), Uuid::new_v4(), Uuid::new_v4());
        let mut b = Boards::default();
        b.place(outer, inner, 1.0, 1.0).unwrap();
        b.place(outer, card, 2.0, 2.0).unwrap();
        b.add_note(inner, 0.0, 0.0, "").unwrap();
        b.forget_node(inner);
        assert!(b.board(inner).is_none());
        assert_eq!(b.board(outer).unwrap().positions.len(), 1);
        b.forget_node(card);
        assert!(b.boards.is_empty());
    }
}
