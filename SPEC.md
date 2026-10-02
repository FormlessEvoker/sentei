# Sentei Specification

## Purpose

`sentei` converts a locally saved HTML document into clean GitHub-Flavored Markdown. It removes page chrome and non-content markup before invoking Pandoc.

Primary use case: save or paste authenticated documentation HTML into a local file, then convert it without giving a browser extension or external service access to proprietary content.

## Security boundaries

- Operate locally only.
- Never fetch URLs, load remote assets, submit telemetry, or execute embedded content.
- Treat HTML as untrusted input.
- Do not read referenced local files or follow links.
- Never modify the source file.
- Refuse to overwrite output unless explicitly requested.
- Avoid placing source HTML or extracted content in logs or error messages.

## Command

```text
sentei [options] INPUT
sentei [options] -
```

`INPUT` is an HTML file. `-` reads HTML from standard input. Markdown is written to standard output unless `--output` is provided.

### Initial options

```text
-o, --output PATH          Write Markdown to PATH
    --force                Allow replacement of an existing output file
    --selector CSS         Use matching element as content root
    --remove CSS           Remove matching elements; repeatable
    --base-url URL         Resolve relative links without fetching them
    --no-extract           Clean and convert the complete body
    --keep-intermediate    Retain cleaned HTML for troubleshooting
    --verbose              Report processing decisions, never document content
-h, --help                 Show help
-v, --version              Show version
```

Invalid selectors, missing files, empty input, ambiguous selector matches, and unavailable dependencies must produce clear failures.

## Processing pipeline

1. Read input with a bounded size (maximum 10 MiB) and detect invalid or empty content.
2. Parse as HTML without executing scripts or resolving external resources.
3. Remove `head`, `script`, `style`, `template`, `noscript`, embedded objects, forms, and other non-document content.
4. Apply every user-supplied `--remove` selector.
5. Select content root:
   - Use `--selector` when supplied; require exactly one match.
   - Otherwise prefer a meaningful `main`, `[role="main"]`, or `article` element.
   - If several candidates exist, select the candidate with the greatest meaningful text content and report that decision under `--verbose`.
   - Fall back to `body` only when no stronger candidate exists.
6. Remove boilerplate within selected root, including navigation, repeated controls, hidden elements, and empty wrappers. Do not remove content solely because of class-name guesses.
7. Normalize markup conservatively:
   - Preserve heading hierarchy, paragraphs, lists, block quotes, links, images, tables, definition lists, and horizontal rules.
   - Preserve `pre` and `code` content exactly apart from line-ending normalization.
   - Preserve meaningful image alternative text.
   - Resolve relative links only when `--base-url` is supplied.
   - Remove presentation-only attributes and comments.
8. Reject extraction that produces no meaningful content.
9. Pass cleaned HTML to Pandoc and request GitHub-Flavored Markdown.
10. Normalize final whitespace without changing code blocks.
11. Write output atomically when `--output` is used.

`--no-extract` skips content-root selection and boilerplate removal but still performs safe markup cleanup.

## Extraction policy

Deterministic HTML semantics and explicit CSS selectors take priority over heuristics. A readability-style extractor may be added later as an opt-in fallback, but must not silently replace deterministic extraction.

Platform-specific cleanup belongs in explicit, documented selector profiles rather than hidden class-name rules.

## Output expectations

- GitHub-Flavored Markdown suitable for analysis and archival.
- ATX headings and fenced code blocks.
- Tables retained when Pandoc can represent them safely.
- Minimal raw HTML.
- No generated timestamps or machine-specific paths.
- Same input, options, and dependency versions should produce the same output.

Conversion is intentionally lossy for layout, styling, interactive controls, and unsupported complex structures. Warnings should identify dropped structural features without echoing proprietary content.

## Dependencies

- Ruby is the preferred implementation language.
- Use Nokogiri for HTML parsing unless implementation research identifies a safer or simpler maintained alternative.
- Use the installed Pandoc executable for conversion.
- Prefer Ruby standard-library functionality elsewhere.
- Pin Ruby dependencies in a tool-local `Gemfile` and `Gemfile.lock`.
- Check required dependency versions at startup and report actionable errors.

## Exit status

| Status | Meaning |
|---:|---|
| `0` | Conversion succeeded |
| `1` | Invalid arguments or input |
| `2` | Extraction produced no usable content |
| `3` | Pandoc or another required dependency failed |
| `4` | Output could not be written safely |

## Validation

Automated tests should cover:

- Article, `main`, role-based, and body fallback extraction.
- Explicit selector selection and ambiguity.
- Navigation, scripts, styles, forms, and hidden-content removal.
- Heading, list, table, link, image, and fenced-code preservation.
- Code containing HTML-like text.
- Relative-link resolution without network access.
- Empty, malformed, oversized, and non-HTML input.
- Existing output protection and atomic writes.
- Paths containing spaces.
- Pandoc absence and Pandoc conversion failure.
- Verification that tests perform no network access.

Use sanitized fixtures containing no proprietary documentation.

## Deferred features

- URL fetching or authenticated browsing.
- Browser integration.
- OCR or PDF conversion.
- JavaScript rendering.
- Site-specific profiles.
- Batch and concurrent conversion.
- Readability-style heuristic extraction.

Add deferred features only after a demonstrated need and explicit approval.
