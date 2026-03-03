// Blockquote marker (`>`) does not need an unescaper here.
// During HTML conversion, `>` inside text is converted to `&gt;` before the escaping
// pass, so it never appears as a bare `>` that could be mistaken for a blockquote.
