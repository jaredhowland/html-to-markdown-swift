// Sources/marker/marker.swift

/// MarkerEscaping is the Bell character (U+0007 = byte 7).
/// Inserted before markdown special chars during text processing.
/// Matches Go's marker.MarkerEscaping = '\a'.
public let MarkerEscaping: Character = "\u{0007}"

/// MarkerCodeBlockNewline replaces \n inside code blocks to protect
/// them from trimConsecutiveNewlines post-processing.
/// Matches Go's marker.MarkerCodeBlockNewline = '\uF002'.
public let MarkerCodeBlockNewline: Character = "\u{F002}"
