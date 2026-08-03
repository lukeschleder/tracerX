# Changelog

## 0.2.2

- Optional `prefix` on `ConsoleSink` for branded console lines
- Optional `tag` on `TraceEvent` (defaults to session name; overridable per call)
- `filterTag` / `filterTags` on `ConsoleSink` and `FileSink`

## 0.2.1

- Colorized Fix Receipts (`TracerDiff.generateReceipt`)
- Simplified `ConsoleSink` ANSI styling; respect `NO_COLOR`
- Removed flaky `DiffType.reordered` (LCS already covers add/remove)
- Tightened `PiiMasker` to exact sensitive key names
- Real-world checkout example and public API documentation
- README, LICENSE, and publish-oriented package metadata

## 0.2.0

- Session recording (`TracerX` / `TracerSession` / `TracerTrace`)
- `TracerDiff` Fix Receipt engine
- `FileSink`, PII masking, and CI workflow

## 0.1.0

- Initial lightweight logger with stack-trace caller parsing
