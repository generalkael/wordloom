//! Project-wide search across titles, text, synopses, notes and keywords.

use serde::Serialize;

use crate::model::{NodeId, Project, RootRole};

#[cfg(test)]
use crate::model::NodeKind;

#[derive(Serialize, Clone, Debug, PartialEq)]
pub struct Hit {
    pub id: NodeId,
    pub title: String,
    /// Where the match was found: title, text, synopsis, notes, keyword.
    pub field: &'static str,
    pub snippet: String,
    pub count: usize,
}

/// How a search matches: `case` makes it case-sensitive, `word` matches
/// whole words only ("lamp" but not "lamplight").
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Options {
    pub case: bool,
    pub word: bool,
}

fn fold(c: char, case: bool) -> char {
    if case {
        return c;
    }
    // Single-char lowercase covers nearly every script; the few characters
    // whose lowercase is longer ('İ') are compared as they are.
    let mut l = c.to_lowercase();
    match (l.next(), l.next()) {
        (Some(x), None) => x,
        _ => c,
    }
}

fn is_word_char(c: char) -> bool {
    c.is_alphanumeric() || c == '_'
}

/// Byte ranges of every match of `query` in `text`, without overlaps.
pub fn find(text: &str, query: &str, o: Options) -> Vec<(usize, usize)> {
    let needle: Vec<char> = query.chars().map(|c| fold(c, o.case)).collect();
    if needle.is_empty() {
        return Vec::new();
    }
    let hay: Vec<(usize, char)> = text.char_indices().collect();
    let mut out = Vec::new();
    let mut i = 0;
    while i + needle.len() <= hay.len() {
        let hit = needle
            .iter()
            .enumerate()
            .all(|(k, &n)| fold(hay[i + k].1, o.case) == n);
        let end_i = i + needle.len();
        let bounded = !o.word
            || ((i == 0 || !is_word_char(hay[i - 1].1))
                && (end_i == hay.len() || !is_word_char(hay[end_i].1)));
        if hit && bounded {
            let end = hay.get(end_i).map_or(text.len(), |h| h.0);
            out.push((hay[i].0, end));
            i = end_i;
        } else {
            i += 1;
        }
    }
    out
}

/// Search titles, text, synopses, notes and keywords. Results come in binder
/// order, one hit per (item, field). Trashed items are skipped.
pub fn search(p: &Project, query: &str, o: Options) -> Vec<Hit> {
    let q = query.trim();
    if q.is_empty() {
        return Vec::new();
    }
    let mut out = Vec::new();
    for id in searchable(p) {
        let n = &p.nodes[&id];
        let fields: [(&'static str, &str); 4] = [
            ("title", &n.title),
            ("text", p.text(id)),
            ("synopsis", &n.synopsis),
            ("notes", &n.notes),
        ];
        for (field, value) in fields {
            let found = find(value, q, o);
            if let Some(&first) = found.first() {
                out.push(Hit {
                    id,
                    title: n.title.clone(),
                    field,
                    snippet: snippet(value, first),
                    count: found.len(),
                });
            }
        }
        if n.keywords.iter().any(|k| !find(k, q, o).is_empty()) {
            out.push(Hit {
                id,
                title: n.title.clone(),
                field: "keyword",
                snippet: n.keywords.join(", "),
                count: 1,
            });
        }
    }
    out
}

/// Every item outside the Trash, in binder order.
fn searchable(p: &Project) -> Vec<NodeId> {
    p.roots
        .iter()
        .filter(|r| p.nodes[r].role != Some(RootRole::Trash))
        .flat_map(|r| p.subtree(*r))
        .collect()
}

/// About 40 characters either side of the match at byte range `m`.
fn snippet(orig: &str, m: (usize, usize)) -> String {
    let before: Vec<char> = orig[..m.0].chars().collect();
    let after: Vec<char> = orig[m.1..].chars().collect();
    let b = before.len().saturating_sub(40);
    let a = after.len().min(40);
    let mut s = String::new();
    if b > 0 {
        s.push('…');
    }
    s.extend(&before[b..]);
    s.push_str(&orig[m.0..m.1]);
    s.extend(&after[..a]);
    if a < after.len() {
        s.push('…');
    }
    s.replace('\n', " ")
}

/// Replace every match of `find` in document text, outside the Trash, in
/// the documents `only` lists (all of them if it's None). Returns
/// (documents changed, total replacements).
pub fn replace_all(
    p: &mut Project,
    query: &str,
    replace: &str,
    o: Options,
    only: Option<&[NodeId]>,
) -> (usize, usize) {
    if query.is_empty() {
        return (0, 0);
    }
    let (mut docs, mut total) = (0, 0);
    for id in searchable(p) {
        if only.is_some_and(|ids| !ids.contains(&id)) {
            continue;
        }
        let text = p.text(id);
        let found = find(text, query, o);
        if found.is_empty() {
            continue;
        }
        let mut new = String::with_capacity(text.len());
        let mut at = 0;
        for &(a, b) in &found {
            new.push_str(&text[at..a]);
            new.push_str(replace);
            at = b;
        }
        new.push_str(&text[at..]);
        if p.set_text(id, new).is_ok() {
            docs += 1;
            total += found.len();
        }
    }
    (docs, total)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_and_replaces() {
        let any = Options::default();
        let mut p = Project::new("N", "");
        let ms = p.root(RootRole::Manuscript);
        let ch = p.nodes[&ms].children[0];
        let s = p.nodes[&ch].children[0];
        p.set_text(s, "The Dragon slept. A dragon woke.".into())
            .unwrap();
        p.node_mut(s).unwrap().keywords.push("dragons".into());
        let hits = search(&p, "dragon", any);
        assert_eq!(hits.len(), 2);
        assert_eq!(hits[0].field, "text");
        assert_eq!(hits[0].count, 2);
        assert_eq!(replace_all(&mut p, "DRAGON", "wyrm", any, None), (1, 2));
        assert_eq!(p.text(s), "The wyrm slept. A wyrm woke.");
        p.trash(ch).unwrap();
        assert!(search(&p, "wyrm", any).is_empty());
        // Text in the Trash is left alone.
        assert_eq!(replace_all(&mut p, "wyrm", "drake", any, None), (0, 0));
        assert_eq!(p.text(s), "The wyrm slept. A wyrm woke.");
    }

    #[test]
    fn case_and_whole_words() {
        let case = Options {
            case: true,
            word: false,
        };
        let word = Options {
            case: false,
            word: true,
        };
        let t = "Lamp, lamplight, the LAMP and lamp_room. Ölampe";
        assert_eq!(find(t, "lamp", Options::default()).len(), 5);
        assert_eq!(find(t, "lamp", case).len(), 3);
        assert_eq!(find(t, "lamp", word), vec![(0, 4), (21, 25)]);
        assert_eq!(find("ÉTÉ été", "été", Options::default()).len(), 2);
        assert_eq!(find("aaa", "aa", Options::default()).len(), 1);
        assert!(find("x", "", Options::default()).is_empty());
        assert_eq!(snippet("one two three", (4, 7)), "one two three");
    }

    #[test]
    fn replaces_only_chosen_documents() {
        let any = Options::default();
        let mut p = Project::new("N", "");
        let ms = p.root(RootRole::Manuscript);
        let ch = p.nodes[&ms].children[0];
        let a = p.nodes[&ch].children[0];
        let b = p.add_node(ch, None, NodeKind::Text, "B").unwrap();
        p.set_text(a, "Mara ran.".into()).unwrap();
        p.set_text(b, "Mara hid. MARA!".into()).unwrap();
        assert_eq!(replace_all(&mut p, "mara", "Ilse", any, Some(&[b])), (1, 2));
        assert_eq!(p.text(a), "Mara ran.");
        assert_eq!(p.text(b), "Ilse hid. Ilse!");
    }
}
