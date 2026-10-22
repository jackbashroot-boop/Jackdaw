# Contributing

## Commit messages drive the changelog

The changelog is generated from conventional commits, so the commit message is the
changelog entry. Format:

    <type>(<optional scope>): <what changed>

    <why it changed, one line>

Types: `feat`, `fix`, `perf`, `refactor`, `remove`, `security`, `docs`.
Anything else (`chore`, `ci`, `build`, `test`, `style`) is skipped unless it is breaking.

Add `!` after the type, or a `BREAKING CHANGE:` line in the body, for a major bump.

`feat` bumps the minor version. Everything else bumps the patch.

## Use `chore:` for changelog-only commits

A commit that regenerates the changelog can never include itself. Using `chore:`
keeps it out of the output, so regenerating on an unchanged tree produces an
identical file and CI's staleness check stays quiet.

## Regenerate before you push

    dotnet run --project tools/Jackdaw.ChangelogGen

This rewrites `changelog.json` and `CHANGELOG.md`. CI warns if they are stale.
