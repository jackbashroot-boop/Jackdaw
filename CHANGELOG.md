# Changelog

Generated from conventional commits. Edit commit messages, not this file.

## v0.1.0 - 2026-10-22

### Added

- release pipeline building six platforms - Builds self-contained binaries, publishes checksums, and pulls release notes from the changelog. (`
30e459`)
- one-line installers for macos, linux, and windows - Both verify a published sha256 before installing and support --uninstall. (`
16d633`)
- changelog generated from conventional commits - changelog.json is the source of truth and CHANGELOG.md is derived from it, so the two can never disagree. (`
7cc299`)
- cli with version, changelog, and doctor commands - The changelog is embedded in the binary so an installed copy can always show it. (`
7949f2`)
- repository skeleton and shared build properties - Pin the SDK to the .NET 8 LTS channel, centralise package versions, and enable nullable reference types. (`
67361f`)

### Docs

- readme, agent schema, and roadmap - Documents the naming collisions so the shared name is a deliberate choice. (`
c51314`)

