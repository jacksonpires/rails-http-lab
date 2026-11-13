# Bruno format

How `.bru` files are parsed and re-emitted. Everything here serves one goal: [round-trip stability](round-trip-stability.md).

* [Byte-stable round-trip](round-trip-stability.md) - Files written by Bruno must parse and re-emit byte-for-byte identical.
* [Block modes](block-modes.md) - The three block shapes (kv, raw, list) and how the parser picks one.
* [Multi-line values](multiline-values.md) - Unbalanced braces and '''triple quotes''' let a kv value span lines.
* [Disabled keys](disabled-keys.md) - A `~` prefix on a key disables that row without deleting it.
