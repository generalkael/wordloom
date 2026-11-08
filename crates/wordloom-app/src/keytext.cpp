#include "keytext.h"

#include <QKeySequence>

KeyText::KeyText(QObject *parent) : QObject(parent) {}

QString KeyText::fromEvent(int key, int modifiers) const
{
    switch (key) {
    case Qt::Key_Shift:
    case Qt::Key_Control:
    case Qt::Key_Meta:
    case Qt::Key_Alt:
    case Qt::Key_AltGr:
    case Qt::Key_CapsLock:
    case Qt::Key_unknown:
    case 0:
        return QString();
    default:
        break;
    }
    const auto mods = Qt::KeyboardModifiers(modifiers) & ~Qt::KeypadModifier;
    return QKeySequence(QKeyCombination(mods, Qt::Key(key))).toString(QKeySequence::PortableText);
}

QString KeyText::portable(const QString &text) const
{
    const QKeySequence seq = QKeySequence::fromString(text.trimmed(), QKeySequence::PortableText);
    if (seq.count() != 1 || seq[0].key() == Qt::Key_unknown)
        return QString();
    return seq.toString(QKeySequence::PortableText);
}

QString KeyText::nativeText(const QString &text) const
{
    return QKeySequence::fromString(text, QKeySequence::PortableText).toString(QKeySequence::NativeText);
}
