# Sentei

Sentei prunes locally saved web pages and converts their meaningful content into clean GitHub-Flavored Markdown using Nokogiri and Pandoc.

**Status:** Early development. `main` holds the v0.1.0 prototype; the planned implementation proceeds cairn by cairn on the `menhir` branch toward v1.0.0 (see [PLAN.md](PLAN.md)).

Sentei processes files provided by you locally. It does not fetch URLs, load remote assets, execute embedded content, or send content to external services.

## Requirements

- Ruby 3.2 or newer
- Pandoc 2.0 or newer

Install the pinned Ruby dependency with `bundle install`. Run the CLI with `bundle exec ruby bin/sentei INPUT`, or invoke `bin/sentei` after installing Nokogiri in the active Ruby environment.

```sh
bundle exec ruby bin/sentei saved-page.html
bundle exec ruby bin/sentei --selector 'main article' --output page.md saved-page.html
cat saved-page.html | bundle exec ruby bin/sentei -
```

Markdown is written to standard output unless `--output` is provided. Existing output files are never replaced unless `--force` is supplied. `--keep-intermediate` writes cleaned HTML beside the selected Markdown output (or as `sentei.cleaned.html` in the current directory).

See [SPEC.md](SPEC.md) for the complete behavior, security boundaries, and validation requirements.

Run the automated tests with `bundle exec ruby -Itest test/sentei_test.rb`.
