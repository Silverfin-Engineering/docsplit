# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies (open3_safe is fetched from GitHub at a pinned commit ref — see Gemfile)
bundle install

# Run all tests
bundle exec rake test

# Run a single test file
bundle exec ruby test/unit/test_extract_text.rb

# Build and install the gem locally
bundle exec rake gem:install
```

## External Dependencies

The following system tools must be installed for full functionality:
- `gm` (GraphicsMagick) — image extraction and OCR pre-processing
- `pdftotext`, `pdfinfo`, `pdftk` — text extraction and PDF metadata
- `tesseract` — OCR (with optional `osd` language pack for orientation detection)
- `java` + JODConverter (vendored in `vendor/`) — non-PDF document conversion
- `open3_safe` gem — pinned to a specific GitHub commit ref in `Gemfile`; `Gemfile.lock` must be regenerated after changing the ref

## Architecture

`lib/docsplit.rb` is the public API entry point. It defines the `Docsplit` module, checks `PATH` for dependencies at load time, and delegates to extractor classes.

**Extractor classes** (`lib/docsplit/`):
- `TextExtractor` — extracts text via `pdftotext`, falls back to Tesseract OCR for pages below `MIN_TEXT_PER_PAGE` (100 bytes)
- `ImageExtractor` — rasterizes PDF pages via GraphicsMagick (`gm convert`/`gm mogrify`)
- `PdfExtractor` — converts non-PDF documents to PDF using LibreOffice or JODConverter (Java)
- `InfoExtractor` — parses `pdfinfo` output for metadata
- `PageExtractor` — bursts PDFs into single-page PDFs via `pdftk`/`pdftailor`

**`ExternalProcess` module** (`external_process.rb`) is mixed into extractor classes. Its `run` method wraps `Open3Safe.capture3_safe` to execute subprocesses with:
- timeout (SIGTERM → SIGKILL after 5s)
- optional RSS memory limit via `max_rss:`
- stdout+stderr merged, blank lines and consecutive duplicate lines filtered (guards against memory bloat from corrupt PDFs — silverfin/issues/1998)

**Timeout-aware public API**: `extract_text_with_timeouts` and `extract_images_with_timeouts` accept `timeout` (overall) and `item_timeout` (per page/file); `extract_pdf_with_timeout` accepts only `timeout`. RSS caps are not part of the public API — each extractor hardcodes its own `MAX_RSS` constant (`TextExtractor`/`ImageExtractor`: 512 MiB, `TextExtractor::TESSERACT_MAX_RSS`: 1 GiB, `PdfExtractor`: 2 GiB) and passes it into `run(..., max_rss:)` internally. The plain `extract_*` variants have no timeouts.

## Test Structure

Tests live in `test/unit/`, use Minitest, and write output to `test/output/` (cleaned up in `teardown`). Fixtures are in `test/fixtures/` — a mix of PDFs, Office docs, and edge-case files (encrypted, unicode, spaces/quotes in filenames).