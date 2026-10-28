# Sentei Implementation Plan

## Goal

Build Sentei as a small, local Ruby CLI that prunes markup that is never document content from saved HTML and converts everything else to GitHub-Flavored Markdown through Pandoc.

Implementation will proceed through independently useful milestones called **cairns**. The completed tool is the **menhir**; final integration and release work is the **capstone**.

## Guiding constraints

- Keep processing local. Never fetch URLs or referenced assets.
- Treat all HTML as untrusted input.
- Remove only what is known not to be content. Never select, rank, or score content.
- Prune by element type or explicit user selectors, never by heuristics.
- Keep Nokogiri responsible for parsing and structural cleanup.
- Keep Pandoc responsible for HTML-to-Markdown conversion.
- Avoid architecture or behavior added only to support thematic naming.
- Add deferred features only after demonstrated need and explicit discussion.

## Proposed project structure

```text
sentei/
├── bin/
│   └── sentei
├── lib/
│   ├── sentei.rb
│   └── sentei/
│       ├── application.rb
│       ├── cli.rb
│       ├── document.rb
│       ├── errors.rb
│       ├── input_reader.rb
│       ├── output_writer.rb
│       ├── pandoc.rb
│       └── version.rb
├── test/
│   ├── fixtures/
│   ├── application_test.rb
│   ├── cli_test.rb
│   ├── document_test.rb
│   ├── output_writer_test.rb
│   └── pandoc_test.rb
├── Gemfile
├── Gemfile.lock
├── README.md
└── SPEC.md
```

This is a target shape, not a requirement to create every file immediately. Each cairn should add only the structure it needs.

## Module boundaries

### `Sentei::CLI`

- Parse command-line arguments with `OptionParser`.
- Display help and version information.
- Validate option combinations.
- Translate typed failures into concise messages and documented exit statuses.

### `Sentei::Application`

- Orchestrate the processing pipeline.
- Pass dependencies and streams explicitly for testability.
- Contain no HTML cleanup, Pandoc invocation, or file-writing details.
- Reject Markdown that is empty after whitespace normalization, without writing output.

### `Sentei::InputReader`

- Read a named file or standard input.
- Enforce the configured maximum input size.
- Reject missing, unreadable, or empty input.
- Never modify the source file.

### `Sentei::Document`

- Parse HTML with Nokogiri.
- Remove unsafe and irrelevant elements.
- Apply explicit removal selectors.
- Perform conservative markup cleanup.
- Resolve relative references when a base URL is supplied.

Initially, `Document` owns this complete transformation. Extract helpers such as `Cleaner` only if its implementation becomes difficult to understand or test.

### `Sentei::Pandoc`

- Locate and validate the Pandoc executable.
- Invoke Pandoc with argument arrays through `Open3`, never through a shell.
- Send cleaned HTML over standard input.
- Return Markdown or raise a typed dependency/conversion failure.

### `Sentei::OutputWriter`

- Write Markdown to standard output or a named path.
- Refuse existing output unless `--force` is present.
- Use safe atomic writes for file output.
- Report output failures without leaking document content.

### `Sentei::Errors`

Define a small typed hierarchy sufficient for exit-status mapping:

- `Sentei::Error`
- `Sentei::InputError`
- `Sentei::SelectorError`
- `Sentei::EmptyOutputError`
- `Sentei::DependencyError`
- `Sentei::ConversionError`
- `Sentei::OutputError`

### `Sentei::VERSION`

Expose the tool version without loading the full application.

## Public interface

The CLI is the initial supported public interface:

```text
sentei [options] INPUT
sentei [options] -
```

The executable should remain a thin adapter:

```ruby
#!/usr/bin/env ruby

require "sentei"

exit Sentei::CLI.run(
  ARGV,
  stdin: $stdin,
  stdout: $stdout,
  stderr: $stderr
)
```

A Ruby library API such as `Sentei.convert(html, **options)` may be added later if a real use case emerges. It is not required for the initial menhir.

## Cairn 1: Conversion spine

Deliver the smallest end-to-end useful conversion.

### Scope

- Establish the minimal Ruby project structure.
- Add pinned Nokogiri dependency and lockfile.
- Accept an HTML file or `-` for standard input.
- Reject missing and empty input clearly.
- Parse HTML with Nokogiri.
- Convert the complete body through installed Pandoc.
- Request GitHub-Flavored Markdown with ATX headings and fenced code blocks.
- Write Markdown to standard output.
- Report missing Nokogiri or Pandoc and Pandoc conversion failures.
- Add focused tests, sanitized fixtures, and initial usage documentation.

### Completion condition

A local HTML document and equivalent standard-input stream both produce expected Markdown, with no network access and clear dependency failures.

## Cairn 2: Safe input and output

Add bounded input and atomic output behavior.

### Scope

- Choose and document an explicit maximum input size.
- Add `--output PATH`.
- Add `--force`.
- Refuse accidental replacement of existing files.
- Write file output atomically.
- Support paths containing spaces.
- Implement stable exit-status mapping.
- Test file races and failure cleanup where practical.

### Completion condition

Input and output behavior satisfies the specification without modifying source files or silently replacing destination files.

## Cairn 3: Pruning

Remove markup that is never document content while preserving everything else.

### Scope

- Remove `head`, scripts, styles, templates, noscript content, embedded objects, forms, and `nav`.
- Remove obviously hidden elements: the `hidden` attribute (except `hidden="until-found"`) and inline `style` declaring `display: none` or `visibility: hidden`.
- Add repeatable `--remove CSS`, failing clearly on invalid selectors.
- Remove comments and presentation-only attributes.
- Preserve headings, paragraphs, lists, block quotes, links, images, tables, definition lists, horizontal rules, `pre`, and `code`.
- Preserve image alternative text.
- Reject input that converts to empty Markdown with `EmptyOutputError`, naming likely causes without echoing content.
- Do not select a content root, guess from class names, evaluate stylesheets or computed styles, or treat `aria-hidden` as hidden.

### Completion condition

Sanitized fixtures lose known non-content elements and user-removed elements while retaining all other content, including multiple articles, headers, footers, asides, and code text.

## Cairn 4: Links and diagnostics

Complete the planned controls and operational feedback.

### Scope

- Add `--base-url URL`.
- Resolve only supported relative URL-bearing attributes without fetching.
- Preserve fragments and already absolute or non-HTTP schemes.
- Add `--verbose` diagnostics that never include document content.
- Check and report dependency versions with actionable failures.
- Add `--keep-intermediate` after defining its destination, naming, and overwrite behavior.

### Completion condition

Relative links resolve deterministically, no network requests occur, and diagnostics reveal decisions without exposing source content.

## Cairn 5: Hardening

Exercise security boundaries and difficult inputs.

### Scope

- Cover malformed, oversized, and non-HTML input.
- Cover code containing HTML-like text.
- Cover invalid `--remove` selectors.
- Cover Pandoc absence and conversion failure.
- Verify source files remain unchanged.
- Verify tests perform no network access.
- Verify deterministic output for fixed input, options, and dependency versions.
- Cover all documented exit statuses.

### Completion condition

All specified failure classes and security boundaries have automated acceptance coverage using sanitized fixtures.

## Capstone: Menhir assembly

Integrate and prepare the first stable local release.

### Scope

- Run end-to-end acceptance tests against representative sanitized saved pages.
- Confirm clean GFM output and minimal raw HTML.
- Confirm no network access, source modification, content-bearing diagnostics, or unsafe overwrites.
- Lock supported Ruby, Nokogiri, and Pandoc versions or version ranges.
- Complete README documentation for installation, usage, options, dependencies, inputs, outputs, limitations, and network behavior.
- Install the `bin/sentei` entrypoint and create the toolbox-level relative symlink after checking for naming conflicts and receiving approval.
- Compare implemented behavior against `SPEC.md`.
- Document intentional deviations and deferred work.
- Assign the first stable local version.

### Completion condition

Sentei can be installed and invoked consistently from the toolbox, satisfies the specification's accepted scope, and has reproducible automated validation.

## Decisions to make at implementation time

These decisions should be made at the cairn where evidence is available:

- Maximum accepted input size.
- Minimum supported Ruby and Pandoc versions.
- Exact Pandoc writer flags.
- Exact elements that count as embedded objects and forms.
- Narrow list of presentation-only attributes.
- Exact inline-style patterns that count as obviously hidden.
- Atomic no-clobber strategy for the supported platforms.
- Destination and lifecycle of retained intermediate HTML.
- Whether Markdown needs any post-Pandoc whitespace normalization.

If a decision materially increases complexity or changes observable behavior, pause and discuss it before implementation.

## Scope gates

The following remain deferred unless real inputs demonstrate a need and expansion is explicitly approved:

- URL fetching or authenticated browsing.
- Browser integration or JavaScript rendering.
- Automatic content-root selection or readability-style extraction.
- `--selector CSS` (convert only one matching element).
- Computed CSS evaluation.
- Class-name-based boilerplate guesses.
- Repeated-layout or repeated-control detection.
- Site-specific cleanup profiles.
- Batch or concurrent conversion.
- OCR or PDF conversion.
- Detailed unsupported-structure analysis.
- Sophisticated Markdown rewriting.
- A supported public Ruby library API.

## Branching and release model

- `main` currently holds the **v0.1.0** prototype: a single-file implementation written ahead of this plan. It is the baseline and is tagged `v0.1.0`. It is not changed during the cairn work.
- `menhir` is the long-lived integration branch for the planned, cairn-by-cairn implementation. It starts from `main`.
- **Cairn 0** strips the prototype from `menhir` (code, tests, and dependency files), leaving only the documentation, so Cairn 1 builds the project from the ground up.
- Each cairn is implemented on its own branch cut from `menhir` and merged back into `menhir` by pull request:
  - `cairn-1-conversion-spine`
  - `cairn-2-safe-input-output`
  - `cairn-3-pruning`
  - `cairn-4-links-diagnostics`
  - `cairn-5-hardening`
  - `capstone-menhir-assembly`
- A cairn branch is merged only when its completion condition is met. Later cairn branches start from the updated `menhir`.
- Each cairn implements only its own scope. Behavior from the v0.1.0 prototype is reintroduced in the cairn that owns it, not carried over wholesale.
- The capstone branch carries final integration, documentation, and version assignment. Once `menhir` is fully tested and the capstone is merged into it, `menhir` is merged into `main` and released as **v1.0.0**.

## Working method

For each cairn:

0. Branch from `menhir` and open the cairn pull request against `menhir`.
1. Confirm unresolved behavior and scope decisions.
2. Implement the smallest complete vertical slice.
3. Add focused automated tests with sanitized fixtures.
4. Validate the exact completion condition.
5. Update README and specification where behavior has been clarified.
6. Review newly discovered complexity before moving it into current scope.
