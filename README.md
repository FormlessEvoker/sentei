# Sentei

Sentei prunes locally saved web pages and converts their meaningful content into clean GitHub-Flavored Markdown using Nokogiri and Pandoc.

**Status:** Cairn 0. The v0.1.0 prototype has been removed from `menhir` so that the implementation can be rebuilt cairn by cairn toward v1.0.0 (see [PLAN.md](PLAN.md)). There is no runnable code yet; the next step is Cairn 1, the conversion spine. The prototype remains available on `main` and as the `v0.1.0` tag.

Sentei processes files provided by you locally. It does not fetch URLs, load remote assets, execute embedded content, or send content to external services.

See [SPEC.md](SPEC.md) for the intended behavior, security boundaries, and validation requirements.
