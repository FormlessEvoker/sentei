# Sentei Specification

## Purpose

`sentei` converts a locally saved HTML document into clean GitHub-Flavored Markdown. It prunes markup that is never document content before invoking Pandoc.

Primary use case: save or paste authenticated documentation HTML into a local file, then convert it without giving a browser extension or external service access to proprietary content.

## Security boundaries

- Operate locally only.
- Never fetch URLs, load remote assets, submit telemetry, or execute embedded content.
- Treat HTML as untrusted input.
- Do not read referenced local files or follow links.
- Never modify the source file.
- Refuse to overwrite output unless explicitly requested.
- Avoid placing source HTML or document content in logs or error messages.

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
    --remove CSS           Remove matching elements; repeatable
    --base-url URL         Resolve relative links without fetching them
    --keep-intermediate    Retain cleaned HTML for troubleshooting
    --verbose              Report processing decisions, never document content
-h, --help                 Show help
-v, --version              Show version
```

Invalid selectors, missing files, empty input, and unavailable dependencies must produce clear failures.

## Processing pipeline

1. Read input with a bounded size (maximum 10 MiB) and detect invalid or empty content.
2. Parse as HTML without executing scripts or resolving external resources.
3. Remove elements that are never document content: `head`, `script`, `style`, `template`, `noscript`, embedded objects, forms, and `nav`. Also remove obviously hidden elements: those with the `hidden` attribute (except `hidden="until-found"`, which marks collapsed but findable content) and those whose inline `style` declares `display: none` or `visibility: hidden`.
4. Apply every user-supplied `--remove` selector.
5. Normalize markup conservatively:
   - Preserve heading hierarchy, paragraphs, lists, block quotes, links, images, tables, definition lists, and horizontal rules.
   - Preserve `pre` and `code` content exactly apart from line-ending normalization.
   - Preserve image alternative text.
   - Resolve relative links only when `--base-url` is supplied.
   - Remove presentation-only attributes and comments.
6. Pass the remaining `body` to Pandoc and request GitHub-Flavored Markdown.
7. Normalize final whitespace without changing code blocks.
8. Reject the result if the Markdown is empty after whitespace normalization. Write nothing, and report likely causes (for example, a page that requires JavaScript, or a `--remove` selector that matched everything) without echoing content.
9. Write output atomically when `--output` is used.

## Pruning policy

Sentei removes markup that is known not to be document content. It does not select, rank, or score content, and it does not decide which part of a page matters. Everything that is not removed is converted, including multiple articles, headers, footers, and sidebars.

Removal is by element type (pipeline step 3) or by explicit user selectors (`--remove`), never by class-name guesses, stylesheets, computed styles, or other heuristics. Hidden content is removed only when the element's own markup declares it hidden; `aria-hidden` does not count, because it hides content from assistive technology rather than from the page. When it is unclear whether something is content, keep it.

Site-specific cleanup, if added later, belongs in explicit, documented selector profiles rather than hidden rules.

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
| `2` | No content remained after pruning |
| `3` | Pandoc or another required dependency failed |
| `4` | Output could not be written safely |

## Validation

Automated tests should cover:

- Navigation, scripts, styles, forms, embedded-object, and obviously hidden-element removal, including retention of `hidden="until-found"` and `aria-hidden` content.
- `--remove` selectors, including invalid selectors.
- Preservation of content outside `main` and `article`, such as multiple articles, headers, footers, and asides.
- Heading, list, table, link, image, and fenced-code preservation.
- Code containing HTML-like text.
- Relative-link resolution without network access.
- Empty, malformed, oversized, and non-HTML input.
- Rejection of input that converts to empty Markdown.
- Existing output protection and atomic writes.
- Paths containing spaces.
- Pandoc absence and Pandoc conversion failure.
- Verification that tests perform no network access.

Use sanitized fixtures containing no proprietary documentation.

## Deferred features

- `--selector CSS`: convert only the single element matching a selector. An optional enhancement to consider after the initial release, not part of it.
- URL fetching or authenticated browsing.
- Browser integration.
- OCR or PDF conversion.
- JavaScript rendering.
- Site-specific profiles.
- Batch and concurrent conversion.
- Automatic content-root selection or readability-style heuristic extraction.

Add deferred features only after a demonstrated need and explicit approval.
