# Sentei

Sentei prunes locally saved web pages and converts what remains into clean GitHub-Flavored Markdown using Nokogiri and Pandoc.

**Status:** Cairn 2, safe input and output. Sentei converts the complete `<body>` of a local HTML document to Markdown, with bounded input and atomic, no-clobber file output. Pruning and the remaining options arrive in later cairns (see [PLAN.md](PLAN.md)). The v0.1.0 prototype remains available on `main` and as the `v0.1.0` tag.

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
bin/sentei --output page.md saved-page.html
bin/sentei --output page.md --force saved-page.html
```

Markdown is written to standard output with ATX headings, fenced code blocks, and unwrapped lines.

Input larger than **10 MiB** is rejected; reading stops one byte past the limit, so oversized input cannot exhaust memory. Real saved pages are normally far smaller.

With `--output`, Markdown is written to a temporary file in the destination directory and moved into place atomically, so the destination is never left partially written and temporary files are removed on failure. An existing destination is never replaced unless `--force` is given, and the check is race-free: if another process creates the file during conversion, Sentei refuses rather than overwriting it. A symlink at the destination counts as existing, even if its target is missing. The race-free check relies on hard links, so without `--force` the destination must be on a filesystem that supports them (any ordinary macOS or Linux filesystem); otherwise Sentei exits with status 4. Sentei also refuses to replace its own input file. Paths may contain spaces. Nothing is written to standard output when `--output` is used.

| Option | Meaning |
|---|---|
| `-o`, `--output PATH` | Write Markdown to `PATH` instead of standard output |
| `--force` | Allow `--output` to replace an existing file (requires `--output`) |
| `-h`, `--help` | Show help |
| `-v`, `--version` | Show version |

Input is read as UTF-8 when it is valid UTF-8; otherwise the encoding declared by a byte-order mark or `<meta charset>` is used.

## Exit status

| Status | Meaning |
|---:|---|
| `0` | Conversion succeeded |
| `1` | Invalid arguments or input (missing, unreadable, empty, or oversized) |
| `2` | No content remained after pruning (reserved; arrives with pruning in a later cairn) |
| `3` | Nokogiri or Pandoc is unavailable, or Pandoc failed |
| `4` | Output could not be written safely (existing file without `--force`, missing or unwritable directory, write failure) |

Error messages never include document content.

## Development

```sh
bundle exec rake test
```

Tests that need Pandoc are skipped when it is not installed.
