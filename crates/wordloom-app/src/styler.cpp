// Include through the same path as the generated bridge header so the
// header is seen once.
#include "wordloom/src/styler.h"
#include "wordloom/src/styling.cxx.h" // spell_ok(), implemented in Rust

#include "inputsim.h"
#include "pdfexport.h"

#include <QRegularExpression>
#include <QTextBlock>
#include <QTextCursor>
#include <QTimer>
#include <QTextCharFormat>
#include <QTextLayout>
#include <QTextDocument>
#include <QtQml/qqml.h>
#include <algorithm>
#include <vector>

static bool isWordChar(QChar c)
{
    return c.isLetter() || c == QLatin1Char('\'') || c == QChar(0x2019);
}

// Red wavy underline under words the spell checker rejects. Words that look
// like part of a web or email address are skipped.
void MarkdownHighlighter::underlineMisspellings(const QString &text, const std::vector<char> &marker)
{
    const int n = int(text.size());
    for (int i = 0; i < n;) {
        if (!text[i].isLetter()) {
            ++i;
            continue;
        }
        int j = i;
        while (j < n && isWordChar(text[j]) && !marker[j])
            ++j;
        int end = j;
        while (end > i && !text[end - 1].isLetter()) // trailing apostrophes
            --end;
        const QChar before = i > 0 ? text[i - 1] : QChar();
        const QChar after = j < n ? text[j] : QChar();
        // Letters straight after a digit are an ordinal or unit (2nd, 10km).
        const bool address = before.isDigit() || before == QLatin1Char('/') || before == QLatin1Char('@') || before == QLatin1Char('.')
            || after == QLatin1Char('@') || after == QLatin1Char(':') || after.isDigit()
            || (after == QLatin1Char('.') && j + 1 < n && text[j + 1].isLetter());
        if (end - i > 1 && !address) {
            const QByteArray utf8 = text.mid(i, end - i).toUtf8();
            if (!spell_ok(rust::Str(utf8.constData(), size_t(utf8.size())))) {
                for (int k = i; k < end; ++k) {
                    QTextCharFormat f = format(k);
                    // Qt Quick draws underline colours unreliably (and not on
                    // bold/italic runs), so misspellings get a red tint and
                    // red text, plus the underline where it does render.
                    f.setBackground(spellTint);
                    f.setForeground(spellColor);
                    f.setUnderlineStyle(QTextCharFormat::SpellCheckUnderline);
                    f.setUnderlineColor(spellColor);
                    setFormat(k, 1, f);
                }
            }
        }
        i = j > i ? j : i + 1;
    }
}

// A soft tint behind words repeated nearby in the paragraph (wordloom-core's
// repeats.rs decides which).
void MarkdownHighlighter::tintRepeats(const QString &text)
{
    const QByteArray utf8 = text.toUtf8();
    const rust::Vec<uint32_t> spans = repeated_words(rust::Str(utf8.constData(), size_t(utf8.size())));
    for (size_t i = 0; i + 1 < spans.size(); i += 2) {
        for (int k = int(spans[i]); k < int(spans[i + 1]) && k < int(text.size()); ++k) {
            QTextCharFormat f = format(k);
            f.setBackground(repeatTint);
            setFormat(k, 1, f);
        }
    }
}

MarkdownHighlighter::MarkdownHighlighter(QTextDocument *doc)
    : QSyntaxHighlighter(doc)
{
}

// Emphasis left open at the end of a line carries on to the next line of
// the same paragraph (compile joins a paragraph's lines). The open runs are
// packed into the block state, 2 bits each, innermost last; a blank line
// ends the paragraph and resets it.
static int packOpen(const std::vector<int> &runs)
{
    int state = 0;
    for (size_t i = 0; i < runs.size() && i < 8; ++i)
        state |= (runs[i] & 3) << (2 * i);
    return state;
}

static std::vector<int> unpackOpen(int state)
{
    std::vector<int> runs;
    if (state <= 0)
        return runs;
    for (int i = 0; i < 8; ++i) {
        const int r = (state >> (2 * i)) & 3;
        if (!r)
            break;
        runs.push_back(r);
    }
    return runs;
}

void MarkdownHighlighter::highlightBlock(const QString &text)
{
    QTextCharFormat mark;
    mark.setForeground(markColor);
    if (text.trimmed().isEmpty()) {
        setCurrentBlockState(0);
        return;
    }
    if (!styling) { // spell checking and repeats only
        if (repeats)
            tintRepeats(text);
        if (spellCheck)
            underlineMisspellings(text, std::vector<char>(size_t(text.size()), 0));
        setCurrentBlockState(0);
        return;
    }
    const std::vector<int> carried = unpackOpen(previousBlockState());

    // Scene break: a line of only *, - or _ (at least three), as in compile.
    static const QRegularExpression rule(QStringLiteral("^\\s*([*_-]\\s*){3,}$"));
    if (rule.match(text).hasMatch()) {
        QTextCharFormat f = mark;
        f.setFontWeight(QFont::Bold);
        setFormat(0, int(text.size()), f);
        setCurrentBlockState(0);
        return;
    }

    int body = 0; // where inline text starts
    QTextCharFormat base;

    // Heading: "# Title" … "###### Title".
    static const QRegularExpression heading(QStringLiteral("^(#{1,6})\\s+"));
    const auto h = heading.match(text);
    if (h.hasMatch()) {
        const int level = int(h.capturedLength(1));
        base.setFontWeight(QFont::Bold);
        // Sized from the body text (so they follow zoom): # 1.6×, ## 1.35×,
        // ### 1.15×, deeper levels body size.
        static const double scale[] = { 1.6, 1.35, 1.15, 1.0, 1.0, 1.0 };
        base.setProperty(QTextFormat::FontPixelSize, int(baseSize * scale[level - 1] + 0.5));
        setFormat(0, int(text.size()), base);
        QTextCharFormat m = base;
        m.setForeground(markColor);
        setFormat(0, int(h.capturedLength(0)), m);
        body = int(h.capturedLength(0));
    } else if (text.startsWith(QLatin1Char('>'))) {
        // Block quote.
        base.setFontItalic(true);
        base.setForeground(quoteColor);
        setFormat(0, int(text.size()), base);
        int n = 1;
        while (n < text.size() && (text[n] == QLatin1Char('>') || text[n] == QLatin1Char(' ')))
            ++n;
        setFormat(0, n, mark);
        body = n;
    }

    // Inline comments, {>> … <<} on one line (as in comments.rs): no
    // emphasis inside, tinted, with faded markers.
    const int n = int(text.size());
    std::vector<char> comment(n, 0);
    static const QString cOpen = QStringLiteral("{>>"), cClose = QStringLiteral("<<}");
    std::vector<std::pair<int, int>> comments;
    for (int from = 0;;) {
        const int s = int(text.indexOf(cOpen, from));
        if (s < 0)
            break;
        const int c = int(text.indexOf(cClose, s + 3));
        if (c < 0)
            break;
        comments.push_back({ s, c + 3 });
        std::fill(comment.begin() + s, comment.begin() + c + 3, 1);
        from = c + 3;
    }

    // Inline emphasis: same pairing rules as compile::spans. Runs of up to
    // three * or _ open a style; the same run length closes it; unclosed
    // markers style to the end of the line; _ inside a word is literal.
    std::vector<char> bold(n, 0), italic(n, 0), marker(n, 0);
    struct Open { int run; int pos; };
    std::vector<Open> open;
    // Runs still open from earlier lines start "before" this one.
    for (int r : carried)
        open.push_back({ r, body - r });
    for (int i = body; i < n;) {
        const QChar c = text[i];
        if (comment[i] || (c != QLatin1Char('*') && c != QLatin1Char('_'))) {
            ++i;
            continue;
        }
        int run = 0;
        while (i + run < n && text[i + run] == c && run < 3 && !comment[i + run])
            ++run;
        const bool insideWord = c == QLatin1Char('_') && i > 0 && text[i - 1].isLetterOrNumber()
            && i + run < n && text[i + run].isLetterOrNumber();
        if (insideWord) {
            ++i;
            continue;
        }
        for (int k = 0; k < run; ++k)
            marker[i + k] = 1;
        if (!open.empty() && open.back().run == run) {
            const Open o = open.back();
            open.pop_back();
            for (int k = std::max(body, o.pos + o.run); k < i; ++k) {
                if (comment[k]) continue;
                if (run >= 2) bold[k] = 1;
                if (run != 2) italic[k] = 1;
            }
        } else {
            open.push_back({ run, i });
        }
        i += run;
    }
    std::vector<int> stillOpen;
    for (const Open &o : open) {
        stillOpen.push_back(o.run);
        for (int k = std::max(body, o.pos + o.run); k < n; ++k) {
            if (comment[k]) continue;
            if (o.run >= 2) bold[k] = 1;
            if (o.run != 2) italic[k] = 1;
        }
    }
    setCurrentBlockState(packOpen(stillOpen));

    for (int i = body; i < n;) {
        int j = i;
        while (j < n && bold[j] == bold[i] && italic[j] == italic[i] && marker[j] == marker[i])
            ++j;
        if (bold[i] || italic[i] || marker[i]) {
            QTextCharFormat f = base;
            if (bold[i]) f.setFontWeight(QFont::Bold);
            if (italic[i]) f.setFontItalic(true);
            if (marker[i]) f.setForeground(markColor);
            setFormat(i, j - i, f);
        }
        i = j;
    }

    for (const auto &[s, e] : comments) {
        for (int k = s; k < e; ++k) {
            QTextCharFormat f = format(k);
            f.setBackground(commentTint);
            f.setFontItalic(false);
            f.setFontWeight(QFont::Normal);
            if (k < s + 3 || k >= e - 3) {
                f.setForeground(markColor);
                marker[k] = 1;
            } else {
                f.clearForeground();
            }
            setFormat(k, 1, f);
        }
    }

    // Footnotes (footnotes.rs): a definition line "[^label]: …" is shown in
    // the quote colour; every "[^label]" is faded and not spell-checked.
    static const QRegularExpression noteDef(QStringLiteral("^\\[\\^[^\\]\\s\\[^]+\\]:"));
    if (noteDef.match(text).hasMatch()) {
        for (int k = 0; k < n; ++k) {
            QTextCharFormat f = format(k);
            f.setForeground(quoteColor);
            setFormat(k, 1, f);
        }
    }
    static const QRegularExpression noteRef(QStringLiteral("\\[\\^[^\\]\\s\\[^]+\\]"));
    for (auto it = noteRef.globalMatch(text); it.hasNext();) {
        const auto m = it.next();
        for (int k = int(m.capturedStart()); k < int(m.capturedEnd()); ++k) {
            if (comment[k]) continue;
            QTextCharFormat f = format(k);
            f.setForeground(markColor);
            setFormat(k, 1, f);
            marker[k] = 1;
        }
    }

    // Last, so the styling above doesn't overwrite the marks.
    if (repeats)
        tintRepeats(text);
    if (spellCheck)
        underlineMisspellings(text, marker);
}

MarkdownStyler::MarkdownStyler(QObject *parent)
    : QObject(parent)
{
}

void MarkdownStyler::setDocument(QQuickTextDocument *document)
{
    if (m_document == document)
        return;
    m_document = document;
    attach();
    watchDocument();
    layoutBlocks();
    Q_EMIT documentChanged();
}

// Replacing the text (TextEdit.text = …) resets every paragraph's format and
// empties the undo history. Shortly after any change with an empty history,
// the whole layout is put back. After an edit, the paragraphs it touched
// are fixed up as an undo step of their own (typing "# " un-indents the
// line; the first Ctrl+Z brings the indent back, the second removes the
// "# "). After an undo the formats
// are usually right again, and changing them would lose the redo history,
// so the whole text is checked with the next edit instead.
void MarkdownStyler::watchDocument()
{
    QObject::disconnect(m_contentsConnection);
    QTextDocument *doc = m_document ? m_document->textDocument() : nullptr;
    if (!doc)
        return;
    m_contentsConnection = connect(doc, &QTextDocument::contentsChange, this, [this](int pos, int, int added) {
        if (m_fixing)
            return;
        m_dirtyFrom = m_layoutQueued ? std::min(m_dirtyFrom, pos) : pos;
        m_dirtyTo = m_layoutQueued ? std::max(m_dirtyTo, pos + added) : pos + added;
        if (m_layoutQueued)
            return;
        m_layoutQueued = true;
        QTimer::singleShot(0, this, [this]() {
            m_layoutQueued = false;
            QTextDocument *d = m_document ? m_document->textDocument() : nullptr;
            if (!d)
                return;
            const bool fresh = d->availableUndoSteps() == 0 && !d->isRedoAvailable();
            if (fresh || (m_stale && !d->isRedoAvailable()))
                layoutBlocks();
            else if (d->isRedoAvailable())
                m_stale = true;   // undone: fix everything with the next edit
            else
                fixBlocks(m_dirtyFrom, m_dirtyTo);
        });
    });
}

void MarkdownStyler::setMarkColor(const QColor &c)
{
    if (m_markColor == c)
        return;
    m_markColor = c;
    attach();
    Q_EMIT markColorChanged();
}

void MarkdownStyler::setQuoteColor(const QColor &c)
{
    if (m_quoteColor == c)
        return;
    m_quoteColor = c;
    attach();
    Q_EMIT quoteColorChanged();
}

void MarkdownStyler::setEnabled(bool on)
{
    if (m_enabled == on)
        return;
    m_enabled = on;
    attach();
    Q_EMIT enabledChanged();
}

void MarkdownStyler::setSpellCheck(bool on)
{
    if (m_spellCheck == on)
        return;
    m_spellCheck = on;
    attach();
    Q_EMIT spellCheckChanged();
}

void MarkdownStyler::setCommentColor(const QColor &c)
{
    if (m_commentColor == c)
        return;
    m_commentColor = c;
    attach();
    Q_EMIT commentColorChanged();
}

void MarkdownStyler::setRepeats(bool on)
{
    if (m_repeats == on)
        return;
    m_repeats = on;
    attach();
    Q_EMIT repeatsChanged();
}

void MarkdownStyler::setRepeatColor(const QColor &c)
{
    if (m_repeatColor == c)
        return;
    m_repeatColor = c;
    attach();
    Q_EMIT repeatColorChanged();
}

void MarkdownStyler::setBaseSize(int px)
{
    if (m_baseSize == px || px <= 0)
        return;
    m_baseSize = px;
    attach();
    if (m_indent > 0)
        layoutBlocks();   // the indent is in ems
    Q_EMIT baseSizeChanged();
}

void MarkdownStyler::setLineHeight(qreal h)
{
    h = std::clamp(h, 0.8, 3.0);
    if (qFuzzyCompare(m_lineHeight, h))
        return;
    m_lineHeight = h;
    layoutBlocks();
    Q_EMIT lineHeightChanged();
}

void MarkdownStyler::setFirstLineIndent(qreal em)
{
    em = std::clamp(em, 0.0, 6.0);
    if (qFuzzyCompare(m_indent + 1, em + 1))
        return;
    m_indent = em;
    layoutBlocks();
    Q_EMIT firstLineIndentChanged();
}

void MarkdownStyler::setBlankLineHeight(qreal f)
{
    f = std::clamp(f, 0.1, 1.0);
    if (qFuzzyCompare(m_blankHeight, f))
        return;
    m_blankHeight = f;
    layoutBlocks();
    Q_EMIT blankLineHeightChanged();
}

void MarkdownStyler::applyLayout()
{
    layoutBlocks();
}

namespace {
enum class Kind { Blank, Body, Other };

// What a line is, for layout: blank, body text, or a heading, quote, list
// item or scene break (as in compile.rs and highlightBlock).
Kind kindOf(const QString &text)
{
    static const QRegularExpression other(QStringLiteral(
        "^(#{1,6}\\s|\\s*>|\\s*([*_-]\\s*){3,}$|\\s*([-*+]|\\d+[.)])\\s)"));
    if (text.trimmed().isEmpty())
        return Kind::Blank;
    return other.match(text).hasMatch() ? Kind::Other : Kind::Body;
}

// Body text is indented unless it continues the line above (Markdown joins
// lines up to a blank one) or follows a heading or scene break, as in print.
bool indented(const QTextBlock &b)
{
    if (kindOf(b.text()) != Kind::Body)
        return false;
    QTextBlock p = b.previous();
    if (p.isValid() && kindOf(p.text()) != Kind::Blank)
        return false;
    while (p.isValid() && kindOf(p.text()) == Kind::Blank)
        p = p.previous();
    return p.isValid() && kindOf(p.text()) == Kind::Body;
}
} // namespace

// Gives the paragraphs from `first` up to (not including) `end` their line
// spacing and indent, changing only those that differ, as one undo step.
// Returns whether any did.
bool MarkdownStyler::restyle(QTextBlock b, const QTextBlock &end)
{
    QTextDocument *doc = m_document ? m_document->textDocument() : nullptr;
    if (!doc)
        return false;
    const int line = int(m_lineHeight * 100 + 0.5);
    const int blank = std::max(10, int(m_lineHeight * m_blankHeight * 100 + 0.5));
    const qreal indent = std::round(m_indent * m_baseSize);
    QTextCursor cursor(doc);
    bool changed = false;
    for (; b.isValid() && b != end; b = b.next()) {
        const QTextBlockFormat f = b.blockFormat();
        const int height = kindOf(b.text()) == Kind::Blank ? blank : line;
        const qreal ind = indented(b) ? indent : 0;
        if (f.lineHeightType() == QTextBlockFormat::ProportionalHeight && int(f.lineHeight() + 0.5) == height
            && qFuzzyCompare(f.textIndent() + 1, ind + 1))
            continue;
        if (!changed) {
            m_fixing = true;
            cursor.beginEditBlock();
            changed = true;
        }
        QTextBlockFormat nf = f;
        nf.setLineHeight(height, QTextBlockFormat::ProportionalHeight);
        nf.setTextIndent(ind);
        cursor.setPosition(b.position());
        cursor.setBlockFormat(nf);
    }
    if (changed) {
        cursor.endEditBlock();
        m_fixing = false;
    }
    return changed;
}

// Block formats are part of the document, so setting them adds undo steps,
// and Qt can't set them outside the undo history. Right after the text was
// loaded the history is empty, so it is cleared again after. Otherwise (a
// setting or the zoom changed mid-edit, or an edit needs a fix-up) the
// change is an undo step of its own, after the edit that caused it.
void MarkdownStyler::layoutBlocks()
{
    QTextDocument *doc = m_document ? m_document->textDocument() : nullptr;
    if (!doc)
        return;
    const bool fresh = doc->availableUndoSteps() == 0 && !doc->isRedoAvailable();
    if (restyle(doc->begin(), QTextBlock()) && fresh)
        doc->clearUndoRedoStacks();
    m_stale = false;
}

// After an edit between `from` and `to`: those paragraphs, and the ones just
// around them (whose indent depends on their neighbours).
void MarkdownStyler::fixBlocks(int from, int to)
{
    QTextDocument *doc = m_document ? m_document->textDocument() : nullptr;
    if (!doc)
        return;
    const int last = std::max(0, doc->characterCount() - 1);
    QTextBlock first = doc->findBlock(std::clamp(from, 0, last));
    if (first.previous().isValid())
        first = first.previous();
    QTextBlock end = doc->findBlock(std::clamp(to, 0, last)).next();
    // A blank line's edit can change the indent of the next text paragraph.
    while (end.isValid() && kindOf(end.text()) == Kind::Blank)
        end = end.next();
    if (end.isValid())
        end = end.next();
    restyle(first, end);
}

qreal MarkdownStyler::lineHeightAt(int position) const
{
    QTextDocument *doc = m_document ? m_document->textDocument() : nullptr;
    if (!doc)
        return 0;
    const QTextBlockFormat f = doc->findBlock(position).blockFormat();
    return f.lineHeightType() == QTextBlockFormat::ProportionalHeight ? f.lineHeight() / 100.0 : 1.0;
}

qreal MarkdownStyler::indentAt(int position) const
{
    QTextDocument *doc = m_document ? m_document->textDocument() : nullptr;
    return doc ? doc->findBlock(position).blockFormat().textIndent() : 0;
}

int MarkdownStyler::pixelSizeAt(int position) const
{
    QTextDocument *doc = m_document ? m_document->textDocument() : nullptr;
    if (!doc)
        return 0;
    const QTextBlock block = doc->findBlock(position);
    if (!block.isValid() || !block.layout())
        return 0;
    const int at = position - block.position();
    for (const QTextLayout::FormatRange &r : block.layout()->formats()) {
        if (at >= r.start && at < r.start + r.length && r.format.hasProperty(QTextFormat::FontPixelSize))
            return r.format.intProperty(QTextFormat::FontPixelSize);
    }
    return 0;
}

QColor MarkdownStyler::backgroundAt(int position) const
{
    QTextDocument *doc = m_document ? m_document->textDocument() : nullptr;
    if (!doc)
        return QColor(Qt::transparent);
    const QTextBlock block = doc->findBlock(position);
    if (!block.isValid() || !block.layout())
        return QColor(Qt::transparent);
    const int at = position - block.position();
    for (const QTextLayout::FormatRange &r : block.layout()->formats()) {
        if (at >= r.start && at < r.start + r.length && r.format.hasProperty(QTextFormat::BackgroundBrush))
            return r.format.background().color();
    }
    return QColor(Qt::transparent);
}

void MarkdownStyler::rehighlight()
{
    if (m_highlighter)
        m_highlighter->rehighlight();
}

void MarkdownStyler::attach()
{
    QTextDocument *doc = m_document ? m_document->textDocument() : nullptr;
    // Styling, spell checking or repeats need the highlighter.
    if ((!m_enabled && !m_spellCheck && !m_repeats) || !doc) {
        if (m_highlighter) {
            m_highlighter->setDocument(nullptr);
            delete m_highlighter;
        }
        return;
    }
    if (!m_highlighter || m_highlighter->document() != doc) {
        delete m_highlighter;
        m_highlighter = new MarkdownHighlighter(doc);
    }
    m_highlighter->styling = m_enabled;
    m_highlighter->spellCheck = m_spellCheck;
    m_highlighter->markColor = m_markColor;
    m_highlighter->quoteColor = m_quoteColor;
    m_highlighter->commentTint = m_commentColor;
    m_highlighter->repeats = m_repeats;
    m_highlighter->repeatTint = m_repeatColor;
    m_highlighter->baseSize = m_baseSize;
    m_highlighter->rehighlight();
}

void register_styler_types()
{
    qmlRegisterType<MarkdownStyler>("com.wordloom.styling", 1, 0, "MarkdownStyler");
    qmlRegisterType<PdfExporter>("com.wordloom.styling", 1, 0, "PdfExporter");
    qmlRegisterType<InputSim>("com.wordloom.styling", 1, 0, "InputSim");
}
