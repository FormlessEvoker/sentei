# Sentei

Sentei prunes locally saved web pages and converts their meaningful content into clean GitHub-Flavored Markdown using Nokogiri and Pandoc.

**Status:** Cairn 1, the conversion spine. Sentei converts the complete `<body>` of a local HTML document to Markdown. Extraction, cleanup, and the remaining options arrive in later cairns (see [PLAN.md](PLAN.md)). The v0.1.0 prototype remains available on `main` and as the `v0.1.0` tag.

Sentei processes files provided by you locally. It does not fetch URLs, load remote assets, execute embedded content, or send content to external services. Pandoc runs with `--sandbox`, so it cannot read files or access the network either.

See [SPEC.md](SPEC.md) for the intended behavior, security boundaries, and validation requirements.

## Requirements

- Ruby 3.2 or newer (developed with Ruby 4.0)
- Bundler
- [Pandoc](https://pandoc.org) 2.15 or newer on `PATH` (developed with Pandoc 3.12)

Install the pinned Ruby dependencies from the Sentei directory:

```sh
bundle install
```

## Usage

```sh
bin/sentei saved-page.html > page.md
bin/sentei - < saved-page.html > page.md
```

Markdown is written to standard output with ATX headings, fenced code blocks, and unwrapped lines.

| Option | Meaning |
|---|---|
| `-h`, `--help` | Show help |
| `-v`, `--version` | Show version |

Input is read as UTF-8 when it is valid UTF-8; otherwise the encoding declared by a byte-order mark or `<meta charset>` is used.

## Exit status

| Status | Meaning |
|---:|---|
| `0` | Conversion succeeded |
| `1` | Invalid arguments or input (missing, unreadable, or empty) |
| `3` | Nokogiri or Pandoc is unavailable, or Pandoc failed |

Error messages never include document content.

## Development

```sh
bundle exec rake test
```

Tests that need Pandoc are skipped when it is not installed.
