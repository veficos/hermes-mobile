# Hermes patches

The upstream `xterm` 4.0.0 painter ignored `offset.dy` for vertical-bar and
underline cursors. As a result those cursors were painted at the top of the
canvas instead of at the terminal buffer cursor row.

`lib/src/ui/painter.dart` preserves the complete cell offset for both cursor
types. The block cursor already used the correct offset and is unchanged.
