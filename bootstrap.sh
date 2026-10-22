#!/usr/bin/env bash
#
# Jackdaw bootstrap - writes the Phase 0 tree, commits it, and pushes.
#
#   bash bootstrap.sh
#
# Options:
#   --skip-existing   leave files that already exist alone
#   --no-push         commit locally only
#   --no-changelog    skip running the changelog generator
#
set -euo pipefail

REPO="jackbashroot-boop/Jackdaw"
DESCRIPTION="A local-first personal AI that spawns sub-agents, watches your PC and LAN, and stays out of the way while you game."
TOPICS="ai-agents,blue-team,security,dotnet,local-first,home-lab,monitoring,llm"

SKIP_EXISTING=0
DO_PUSH=1
RUN_GEN=1

for arg in "$@"; do
  case "$arg" in
    --skip-existing) SKIP_EXISTING=1 ;;
    --no-push)       DO_PUSH=0 ;;
    --no-changelog)  RUN_GEN=0 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [ ! -d .git ]; then
  echo "Not inside a git repository. Clone it first:" >&2
  echo "  git clone https://github.com/$REPO.git && cd Jackdaw" >&2
  exit 1
fi

if ! git remote get-url origin 2>/dev/null | grep -q Jackdaw; then
  echo "warning: the 'origin' remote does not look like $REPO" >&2
fi

# An empty clone has no HEAD yet.
git rev-parse --verify HEAD >/dev/null 2>&1 || git checkout -b main 2>/dev/null || true

if [ -z "$(git config user.email || true)" ]; then
  git config user.email "jackbashroot-boop@users.noreply.github.com"
  git config user.name  "jackbashroot-boop"
  echo "note: set a local git identity so commits are attributed"
fi

write() {
  local path="$1"
  if [ -e "$path" ] && [ "$SKIP_EXISTING" = 1 ]; then
    cat > /dev/null
    printf '  kept     %s\n' "$path"
    return
  fi
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  printf '  wrote    %s\n' "$path"
}

commit() {
  git add -A
  if git diff --cached --quiet; then return; fi
  git commit -q -m "$1" -m "${2:-}"
  printf '  commit   %s\n' "$1"
}

echo
echo "Writing files"
echo

# ---------------------------------------------------------------- skeleton ---

write .gitattributes <<'JACKDAW_EOF'
* text=auto eol=lf
*.cmd text eol=crlf
JACKDAW_EOF

write .gitignore <<'JACKDAW_EOF'
bin/
obj/
out/
artifacts/
*.user
*.suo
.vs/
.idea/
.vscode/
.DS_Store
JACKDAW_EOF

write .editorconfig <<'JACKDAW_EOF'
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 4
trim_trailing_whitespace = true

[*.{yml,yaml,json,toml,md}]
indent_size = 2

[*.sh]
indent_size = 2
JACKDAW_EOF

write global.json <<'JACKDAW_EOF'
{
  "sdk": {
    "version": "8.0.100",
    "rollForward": "latestFeature"
  }
}
JACKDAW_EOF

write Directory.Build.props <<'JACKDAW_EOF'
<Project>
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <LangVersion>latest</LangVersion>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <InvariantGlobalization>true</InvariantGlobalization>
    <Version>0.1.0</Version>
    <Authors>jackbashroot-boop</Authors>
    <Product>Jackdaw</Product>
    <RepositoryUrl>https://github.com/jackbashroot-boop/Jackdaw</RepositoryUrl>
    <RepositoryType>git</RepositoryType>
    <PackageLicenseExpression>MIT</PackageLicenseExpression>
    <DebugType>embedded</DebugType>
    <IncludeSourceRevisionInInformationalVersion>false</IncludeSourceRevisionInInformationalVersion>
  </PropertyGroup>
</Project>
JACKDAW_EOF

write Directory.Packages.props <<'JACKDAW_EOF'
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>

  <!--
    Central package management. Any <PackageReference> added to a project MUST have a
    matching <PackageVersion> here, or the build fails with NU1010.
  -->
  <ItemGroup>
    <!-- <PackageVersion Include="Velopack" Version="0.0.0" /> -->
  </ItemGroup>
</Project>
JACKDAW_EOF

write Jackdaw.slnx <<'JACKDAW_EOF'
<Solution>
  <Project Path="src/Jackdaw.Cli/Jackdaw.Cli.csproj" />
  <Project Path="tools/Jackdaw.ChangelogGen/Jackdaw.ChangelogGen.csproj" />
</Solution>
JACKDAW_EOF

write LICENSE <<'JACKDAW_EOF'
MIT License

Copyright (c) 2026 jackbashroot-boop

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
JACKDAW_EOF

commit "feat: repository skeleton and shared build properties" \
       "Pin the SDK to the .NET 8 LTS channel, centralise package versions, and enable nullable reference types."

# --------------------------------------------------------------------- cli ---

write src/Jackdaw.Cli/Jackdaw.Cli.csproj <<'JACKDAW_EOF'
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <AssemblyName>jackdaw</AssemblyName>
    <RootNamespace>Jackdaw.Cli</RootNamespace>
    <RuntimeIdentifiers>win-x64;win-arm64;linux-x64;linux-arm64;osx-x64;osx-arm64</RuntimeIdentifiers>
  </PropertyGroup>

  <ItemGroup>
    <EmbeddedResource Include="../../changelog.json" Link="changelog.json" LogicalName="jackdaw.changelog.json" />
  </ItemGroup>

</Project>
JACKDAW_EOF

write src/Jackdaw.Cli/Program.cs <<'JACKDAW_EOF'
using System.Reflection;
using System.Text.Json;

var asm = Assembly.GetExecutingAssembly();
var version = asm.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
              ?? asm.GetName().Version?.ToString(3)
              ?? "0.0.0";

var command = args.Length > 0 ? args[0] : "help";

switch (command)
{
    case "--version":
    case "-v":
    case "version":
        Console.WriteLine($"jackdaw {version}");
        return 0;

    case "changelog":
        PrintChangelog(args.Length > 1 ? args[1] : null);
        return 0;

    case "doctor":
        PrintDoctor(version);
        return 0;

    case "help":
    case "--help":
    case "-h":
        PrintHelp();
        return 0;

    default:
        Console.Error.WriteLine($"jackdaw: unknown command '{command}'");
        Console.Error.WriteLine("Run 'jackdaw help' to see what's available.");
        return 2;
}

void PrintHelp()
{
    Console.WriteLine($"""
        jackdaw {version}

        Usage: jackdaw <command>

        Commands
          changelog [type]   Show the changelog, optionally filtered by type
                             (added, changed, fixed, removed, security)
          doctor             Report host, runtime, and install details
          version            Print the version

        Phase 0 ships the packaging skeleton. Sensors, the model layer, and the
        agent orchestrator arrive in later phases.
        """);
}

void PrintChangelog(string? filter)
{
    var doc = LoadChangelog();
    if (doc is null)
    {
        Console.WriteLine("No changelog found.");
        return;
    }

    var types = new[] { "added", "changed", "fixed", "removed", "security" };
    if (filter is not null && !types.Contains(filter))
    {
        Console.Error.WriteLine($"jackdaw: unknown type '{filter}'. Try one of: {string.Join(", ", types)}");
        return;
    }

    if (doc.Releases.Count == 0)
    {
        Console.WriteLine();
        Console.WriteLine("  Nothing yet.");
        Console.WriteLine();
        return;
    }

    foreach (var release in doc.Releases)
    {
        var items = release.Items.Where(i => filter is null || i.Type == filter).ToList();
        if (items.Count == 0) continue;

        var tag = release.Tag ?? "(unreleased)";
        Console.WriteLine();
        Console.WriteLine($"  {tag}  {release.Date}");
        foreach (var item in items)
        {
            Console.WriteLine($"    [{item.Type,-8}] {item.Title}");
            if (!string.IsNullOrWhiteSpace(item.Desc))
                Console.WriteLine($"               {item.Desc}");
        }
    }

    Console.WriteLine();
}

void PrintDoctor(string v)
{
    Console.WriteLine($"jackdaw        {v}");
    Console.WriteLine($"runtime        {System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription}");
    Console.WriteLine($"rid            {System.Runtime.InteropServices.RuntimeInformation.RuntimeIdentifier}");
    Console.WriteLine($"os             {System.Runtime.InteropServices.RuntimeInformation.OSDescription}");
    Console.WriteLine($"arch           {System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture}");
    Console.WriteLine($"cpus           {Environment.ProcessorCount}");
    Console.WriteLine($"elevated       {IsElevated()}");
    Console.WriteLine($"exe            {Environment.ProcessPath}");
}

bool IsElevated()
{
    if (!OperatingSystem.IsWindows()) return Environment.UserName == "root";
    using var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
    var principal = new System.Security.Principal.WindowsPrincipal(identity);
    return principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
}

ChangelogDoc? LoadChangelog()
{
    var stream = asm.GetManifestResourceStream("jackdaw.changelog.json");
    if (stream is null) return null;

    using (stream)
    {
        return JsonSerializer.Deserialize<ChangelogDoc>(
            stream,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
    }
}

internal sealed record ChangelogDoc(int Schema, List<ChangelogRelease> Releases);

internal sealed record ChangelogRelease(string Version, string Date, string? Tag, List<ChangelogItem> Items);

internal sealed record ChangelogItem(string Type, string Title, string Desc, string? Commit);
JACKDAW_EOF

commit "feat: cli with version, changelog, and doctor commands" \
       "The changelog is embedded in the binary so an installed copy can always show it."

# --------------------------------------------------------------- changelog ---

write tools/Jackdaw.ChangelogGen/Jackdaw.ChangelogGen.csproj <<'JACKDAW_EOF'
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <AssemblyName>changeloggen</AssemblyName>
    <RootNamespace>Jackdaw.ChangelogGen</RootNamespace>
  </PropertyGroup>

</Project>
JACKDAW_EOF

write tools/Jackdaw.ChangelogGen/Program.cs <<'JACKDAW_EOF'
using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

var repoRoot = Directory.GetCurrentDirectory();
string? promoteTo = null;
var quiet = false;

for (var i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--repo":
            repoRoot = args[++i];
            break;
        case "--promote":
            promoteTo = args[++i].TrimStart('v', 'V');
            break;
        case "--quiet":
            quiet = true;
            break;
        case "-h":
        case "--help":
            Console.WriteLine("""
                Usage: changeloggen [--repo <path>] [--promote <version>] [--quiet]

                  --promote <version>  Convert the 'unreleased' section into a released
                                       version and stamp it with the date of the newest commit.

                Reads conventional commits from git and writes changelog.json plus a
                generated CHANGELOG.md. changelog.json is the single source of truth;
                CHANGELOG.md is always derived from it.
                """);
            return 0;
        default:
            Console.Error.WriteLine($"changeloggen: unknown argument '{args[i]}'");
            return 2;
    }
}

var jsonPath = Path.Combine(repoRoot, "changelog.json");
var mdPath = Path.Combine(repoRoot, "CHANGELOG.md");

var doc = Load(jsonPath);
doc.Releases.RemoveAll(r => r.Version == "unreleased");

var commits = ReadCommits(repoRoot, LastTag(repoRoot));
var subjectRx = SubjectRx();
var items = commits.Select(ToItem).OfType<ChangelogItem>().ToList();

// Stamp the unreleased section with the newest commit's date, not today's clock.
// Otherwise the file differs every day and every "is it current" check fires.
var date = commits.Count > 0
    ? commits[0].Date
    : DateTime.UtcNow.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

var version = promoteTo ?? "unreleased";
doc.Releases.Insert(0, new ChangelogRelease(
    version,
    date,
    promoteTo is null ? null : $"v{promoteTo}",
    items));

File.WriteAllText(jsonPath, JsonSerializer.Serialize(doc, JsonOptions()) + "\n");
File.WriteAllText(mdPath, RenderMarkdown(doc));

if (!quiet)
{
    var released = doc.Releases.FirstOrDefault(r => r.Version != "unreleased")?.Version ?? "0.0.0";
    Console.WriteLine($"changeloggen: {items.Count} entries from {commits.Count} commits");
    Console.WriteLine($"changeloggen: wrote {Path.GetFileName(jsonPath)} and {Path.GetFileName(mdPath)}");
    Console.WriteLine($"changeloggen: current release {released}, suggested next {SuggestNext(released, commits)}");
}

return 0;

static JsonSerializerOptions JsonOptions() => new()
{
    WriteIndented = true,
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    PropertyNameCaseInsensitive = true,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
};

static ChangelogDoc Load(string path)
{
    if (!File.Exists(path)) return new ChangelogDoc(1, []);

    try
    {
        return JsonSerializer.Deserialize<ChangelogDoc>(File.ReadAllText(path), JsonOptions())
               ?? new ChangelogDoc(1, []);
    }
    catch (JsonException ex)
    {
        throw new InvalidOperationException($"{path} is not valid JSON: {ex.Message}", ex);
    }
}

static Regex SubjectRx() => new(
    @"^(?<type>[a-zA-Z]+)(?:\((?<scope>[^)]+)\))?(?<bang>!)?:\s+(?<title>.+)$",
    RegexOptions.Compiled);

ChangelogItem? ToItem(Commit commit)
{
    var match = subjectRx.Match(commit.Subject);
    if (!match.Success) return null;

    var breaking = match.Groups["bang"].Value == "!"
                   || commit.Body.Contains("BREAKING CHANGE", StringComparison.Ordinal);

    var category = Category(match.Groups["type"].Value);
    if (category is null && !breaking) return null;

    var title = match.Groups["title"].Value.Trim();
    return new ChangelogItem(
        category ?? "changed",
        breaking ? $"{title} (breaking)" : title,
        FirstParagraph(commit.Body),
        commit.Hash.Length >= 7 ? commit.Hash[..7] : commit.Hash);
}

static string? Category(string type) => type.ToLowerInvariant() switch
{
    "feat" => "added",
    "fix" => "fixed",
    "perf" or "refactor" or "revert" => "changed",
    "remove" => "removed",
    "security" => "security",
    "docs" => "docs",
    _ => null
};

static string FirstParagraph(string body)
{
    foreach (var raw in body.Split('\n'))
    {
        var line = raw.Trim();
        if (line.Length == 0) continue;
        if (line.StartsWith("BREAKING CHANGE", StringComparison.Ordinal)) continue;
        return line;
    }

    return string.Empty;
}

static string SuggestNext(string current, List<Commit> commits)
{
    var parts = current.Split('.');
    if (parts.Length != 3 || !parts.All(p => int.TryParse(p, out _))) return "0.1.0";

    var major = int.Parse(parts[0]);
    var minor = int.Parse(parts[1]);
    var patch = int.Parse(parts[2]);

    if (commits.Any(c => c.Subject.Contains('!') || c.Body.Contains("BREAKING CHANGE", StringComparison.Ordinal)))
        return $"{major + 1}.0.0";
    if (commits.Any(c => c.Subject.StartsWith("feat", StringComparison.OrdinalIgnoreCase)))
        return $"{major}.{minor + 1}.0";
    return $"{major}.{minor}.{patch + 1}";
}

static string RenderMarkdown(ChangelogDoc doc)
{
    var sb = new StringBuilder();
    sb.Append("# Changelog\n\n");
    sb.Append("Generated from conventional commits. Edit commit messages, not this file.\n\n");

    foreach (var release in doc.Releases)
    {
        var tag = release.Tag ?? "Unreleased";
        sb.Append($"## {tag} - {release.Date}\n\n");

        if (release.Items.Count == 0)
        {
            sb.Append("Nothing yet.\n\n");
            continue;
        }

        foreach (var group in release.Items.GroupBy(i => i.Type))
        {
            sb.Append($"### {char.ToUpperInvariant(group.Key[0])}{group.Key[1..]}\n\n");

            foreach (var item in group)
            {
                var suffix = item.Commit is null ? string.Empty : $" (`{item.Commit}`)";
                var desc = string.IsNullOrWhiteSpace(item.Desc) ? string.Empty : $" - {item.Desc}";
                sb.Append($"- {item.Title}{desc}{suffix}\n");
            }

            sb.Append('\n');
        }
    }

    return sb.ToString();
}

static List<Commit> ReadCommits(string repo, string? since)
{
    var range = since is null ? "HEAD" : $"{since}..HEAD";
    var psi = new ProcessStartInfo("git")
    {
        WorkingDirectory = repo,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        UseShellExecute = false
    };
    psi.ArgumentList.Add("log");
    psi.ArgumentList.Add(range);
    psi.ArgumentList.Add("--no-merges");
    psi.ArgumentList.Add("--pretty=format:%H%x1f%ad%x1f%s%x1f%b%x1e");
    psi.ArgumentList.Add("--date=short");

    using var process = Process.Start(psi) ?? throw new InvalidOperationException("could not start git");
    var stdout = process.StandardOutput.ReadToEnd();
    var stderr = process.StandardError.ReadToEnd();
    process.WaitForExit();

    if (process.ExitCode != 0)
    {
        if (stderr.Contains("does not have any commits yet", StringComparison.Ordinal)) return [];
        throw new InvalidOperationException($"git log failed: {stderr.Trim()}");
    }

    var commits = new List<Commit>();
    foreach (var chunk in stdout.Split('\x1e', StringSplitOptions.RemoveEmptyEntries))
    {
        var parts = chunk.Split('\x1f');
        if (parts.Length < 4) continue;
        commits.Add(new Commit(parts[0], parts[1], parts[2], parts[3].Trim()));
    }

    return commits;
}

// The newest tag that is an ancestor of HEAD and does NOT point at HEAD itself.
// Without the second condition a release run on a tag sees an empty range and the
// release notes come out blank.
static string? LastTag(string repo)
{
    var head = TryGit(repo, "rev-parse", "HEAD");
    if (head is null) return null;

    var tags = TryGit(repo, "tag", "--merged", "HEAD", "--sort=-v:refname");
    if (tags is null) return null;

    foreach (var tag in tags.Split('\n', StringSplitOptions.RemoveEmptyEntries))
    {
        var commit = TryGit(repo, "rev-parse", $"{tag}^{{commit}}");
        if (commit is not null && commit != head) return tag;
    }

    return null;
}

static string? TryGit(string repo, params string[] arguments)
{
    var psi = new ProcessStartInfo("git")
    {
        WorkingDirectory = repo,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        UseShellExecute = false
    };
    foreach (var argument in arguments) psi.ArgumentList.Add(argument);

    using var process = Process.Start(psi);
    if (process is null) return null;

    var stdout = process.StandardOutput.ReadToEnd();
    process.StandardError.ReadToEnd();
    process.WaitForExit();

    return process.ExitCode == 0 ? stdout : null;
}

internal sealed record Commit(string Hash, string Date, string Subject, string Body);

internal sealed record ChangelogDoc(int Schema, List<ChangelogRelease> Releases);

internal sealed record ChangelogRelease(string Version, string Date, string? Tag, List<ChangelogItem> Items);

internal sealed record ChangelogItem(string Type, string Title, string Desc, string? Commit);
JACKDAW_EOF

write changelog.json <<'JACKDAW_EOF'
{
  "schema": 1,
  "releases": []
}
JACKDAW_EOF

write CHANGELOG.md <<'JACKDAW_EOF'
# Changelog

Generated from conventional commits. Edit commit messages, not this file.

Run `dotnet run --project tools/Jackdaw.ChangelogGen` to regenerate.
JACKDAW_EOF

write CONTRIBUTING.md <<'JACKDAW_EOF'
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
JACKDAW_EOF

commit "feat: changelog generated from conventional commits" \
       "changelog.json is the source of truth and CHANGELOG.md is derived from it, so the two can never disagree."

# --------------------------------------------------------------- installers ---

write install.sh <<'JACKDAW_EOF'
#!/bin/sh
# Jackdaw installer for macOS and Linux.
#   curl -fsSL https://raw.githubusercontent.com/jackbashroot-boop/Jackdaw/main/install.sh | sh
set -eu

REPO="jackbashroot-boop/Jackdaw"
BASE="https://github.com/$REPO/releases"
BIN="jackdaw"

VERSION=""
UNINSTALL=0

say()  { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
die()  { printf 'jackdaw: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --version)   [ $# -ge 2 ] || die "--version needs a value"; VERSION="${2#v}"; shift 2 ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help)
      say "Usage: install.sh [--version X.Y.Z] [--uninstall]"
      say ""
      say "  JACKDAW_HOME     install root (default ~/.local/share/jackdaw)"
      say "  JACKDAW_BIN_DIR  where the launcher goes (default ~/.local/bin)"
      exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

HOME_DIR="${JACKDAW_HOME:-$HOME/.local/share/jackdaw}"
BIN_DIR="${JACKDAW_BIN_DIR:-$HOME/.local/bin}"

if [ "$UNINSTALL" = 1 ]; then
  [ -L "$BIN_DIR/$BIN" ] && rm -f "$BIN_DIR/$BIN"
  rm -rf "$HOME_DIR"
  say "jackdaw uninstalled."
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) info "$BIN_DIR is still on your PATH; you can remove it by hand." ;;
  esac
  exit 0
fi

case "$(uname -s)" in
  Linux)  os_part=linux ;;
  Darwin) os_part=osx ;;
  *) die "unsupported OS: $(uname -s)" ;;
esac

case "$(uname -m)" in
  x86_64|amd64)  arch_part=x64 ;;
  arm64|aarch64) arch_part=arm64 ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

rid="$os_part-$arch_part"
asset="$BIN-$rid.tar.gz"

if [ -n "$VERSION" ]; then
  url="$BASE/download/v$VERSION/$asset"
else
  url="$BASE/latest/download/$asset"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

say "Downloading $asset"
curl -fsSL "$url"        -o "$tmp/$asset"        || die "could not download $url"
curl -fsSL "$url.sha256" -o "$tmp/$asset.sha256" || die "could not download the checksum"

say "Verifying checksum"
( cd "$tmp" && if command -v sha256sum >/dev/null 2>&1; then
      sha256sum -c "$asset.sha256"
    else
      shasum -a 256 -c "$asset.sha256"
    fi ) || die "checksum mismatch; refusing to install"

mkdir -p "$HOME_DIR" "$BIN_DIR"
rm -rf "$HOME_DIR/current.tmp"
mkdir -p "$HOME_DIR/current.tmp"
tar -xzf "$tmp/$asset" -C "$HOME_DIR/current.tmp"

[ -f "$HOME_DIR/current.tmp/$BIN" ] || die "archive did not contain $BIN"
chmod +x "$HOME_DIR/current.tmp/$BIN"

rm -rf "$HOME_DIR/previous"
[ -d "$HOME_DIR/current" ] && mv "$HOME_DIR/current" "$HOME_DIR/previous"
mv "$HOME_DIR/current.tmp" "$HOME_DIR/current"

ln -sfn "$HOME_DIR/current/$BIN" "$BIN_DIR/$BIN"

say ""
say "Installed to $BIN_DIR/$BIN"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    say ""
    say "Add this to your shell profile, then restart your shell:"
    info "export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac
JACKDAW_EOF

write install.ps1 <<'JACKDAW_EOF'
#Requires -Version 5.1
<#
.SYNOPSIS
  Jackdaw installer for Windows.

.EXAMPLE
  irm https://raw.githubusercontent.com/jackbashroot-boop/Jackdaw/main/install.ps1 | iex

.EXAMPLE
  & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/jackbashroot-boop/Jackdaw/main/install.ps1'))) -Uninstall
#>
[CmdletBinding()]
param(
    [string]$Version,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$Repo = 'jackbashroot-boop/Jackdaw'
$Base = "https://github.com/$Repo/releases"
$Bin  = 'jackdaw'

function Say  { param([string]$m) Write-Host $m }
function Info { param([string]$m) Write-Host "  $m" }
# Write-Error under ErrorActionPreference=Stop throws before exit 1 runs, which
# wraps the message in an exception dump. Write-Host then exit is cleaner.
function Die  { param([string]$m) Write-Host "jackdaw: $m" -ForegroundColor Red; exit 1 }

$RootDir = if ($env:JACKDAW_HOME) { $env:JACKDAW_HOME } else { Join-Path $env:LOCALAPPDATA 'Jackdaw' }
$BinDir  = Join-Path $RootDir 'bin'

if ($Uninstall) {
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $BinDir "$Bin.cmd")
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $RootDir
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -and (($userPath -split ';') -contains $BinDir)) {
        $cleaned = ($userPath -split ';' | Where-Object { $_ -and $_ -ne $BinDir }) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $cleaned, 'User')
        Info "Removed $BinDir from your user PATH."
    }
    Say 'jackdaw uninstalled.'
    exit 0
}

$arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { 'x64' }
    'ARM64' { 'arm64' }
    default { Die "unsupported architecture: $env:PROCESSOR_ARCHITECTURE" }
}

$rid   = "win-$arch"
$asset = "$Bin-$rid.tar.gz"
$url   = if ($Version) { "$Base/download/v$($Version.TrimStart('v'))/$asset" } else { "$Base/latest/download/$asset" }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("jackdaw-" + [Guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
    Say "Downloading $asset"
    Invoke-RestMethod -Uri $url -OutFile (Join-Path $tmp $asset)
    Invoke-RestMethod -Uri "$url.sha256" -OutFile (Join-Path $tmp "$asset.sha256")

    Say 'Verifying checksum'
    $expected = ((Get-Content (Join-Path $tmp "$asset.sha256") -Raw) -split '\s+')[0].ToLowerInvariant()
    $actual   = (Get-FileHash (Join-Path $tmp $asset) -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($expected -ne $actual) { Die 'checksum mismatch; refusing to install' }

    $stage = Join-Path $RootDir 'current.tmp'
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stage
    New-Item -ItemType Directory -Path $stage -Force | Out-Null

    tar -xzf (Join-Path $tmp $asset) -C $stage
    if ($LASTEXITCODE -ne 0) { Die 'tar extraction failed (needs Windows 10 1803 or newer)' }

    $exe = Join-Path $stage "$Bin.exe"
    if (-not (Test-Path $exe)) { Die "archive did not contain $Bin.exe" }

    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $RootDir 'previous')
    if (Test-Path (Join-Path $RootDir 'current')) {
        Move-Item (Join-Path $RootDir 'current') (Join-Path $RootDir 'previous')
    }
    Move-Item $stage (Join-Path $RootDir 'current')

    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    $shim = Join-Path $BinDir "$Bin.cmd"
    "@echo off`r`n`"%~dp0..\current\$Bin.exe`" %*" | Set-Content -Path $shim -Encoding ASCII

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($userPath -split ';') -notcontains $BinDir) {
        $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $BinDir } else { "$userPath;$BinDir" }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        $env:Path = "$env:Path;$BinDir"
        Say ''
        Say "Added $BinDir to your user PATH. Open a new terminal for it to take effect."
    }

    Say ''
    Say "Installed to $RootDir\current"
    & $exe version
}
finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $tmp
}
JACKDAW_EOF

commit "feat: one-line installers for macos, linux, and windows" \
       "Both verify a published sha256 before installing and support --uninstall."

# ------------------------------------------------------------------ agents ---

write agents/beacon-watcher.toml <<'JACKDAW_EOF'
# A sub-agent. Phase 0 ships the schema; the orchestrator lands in a later phase.
# Sub-agents share the loaded model. They are a system prompt plus a tool
# allowlist, not a new model instance, which is why spawning them is cheap.

role  = "beacon-watcher"
goal  = "Flag hosts making suspiciously regular outbound connections."
model = "tiny"          # tiny | local | cloud
tools = ["conn_table", "dns_log", "firewall_block"]

[trigger]
schedule = "*/5m"

[limits]
max_actions_per_hour = 20
budget_usd_per_day   = 0.10

[policy]
dry_run           = true   # observe only until you approve
requires_approval = ["firewall_block"]
JACKDAW_EOF

write docs/agents.md <<'JACKDAW_EOF'
# Agents

Every sub-agent is a TOML file in `agents/`. Nothing is hidden in code.

| Field | Meaning |
|---|---|
| `role` | Unique name. Also the filename. |
| `goal` | One sentence. This is most of the system prompt. |
| `model` | `tiny` for routing and classification, `local` for reasoning, `cloud` for escalation. |
| `tools` | Allowlist. A sub-agent can only call what is listed. |
| `trigger` | When it runs: `schedule`, `event`, or `manual`. |
| `limits` | Cost and action ceilings so one agent cannot run away. |
| `policy` | `dry_run` and which actions need your approval. |

## Rules

1. **Nothing writes without approval by default.** `dry_run = true` until you flip it.
2. **Tool output arrives as structured JSON**, never raw text, so log content cannot inject instructions into the prompt.
3. **Every action is reversible and logged**, with the evidence that triggered it.
4. **Agents can create agents**, but the new file is written and shown to you before it runs.

Phase 7 adds the self-extension loop. Until then, write these by hand.
JACKDAW_EOF

write README.md <<'JACKDAW_EOF'
# Jackdaw

A local-first personal AI that spawns sub-agents to work on your ideas, watches your
PC and LAN, and stays out of the way while you game.

Status: **Phase 0**. The packaging skeleton is real; the sensors and orchestrator are not.

## Install

macOS and Linux:

    curl -fsSL https://raw.githubusercontent.com/jackbashroot-boop/Jackdaw/main/install.sh | sh

Windows PowerShell:

    irm https://raw.githubusercontent.com/jackbashroot-boop/Jackdaw/main/install.ps1 | iex

Both verify a published SHA-256 before installing, and both support `--uninstall`.

## Use

    jackdaw version
    jackdaw changelog
    jackdaw changelog added
    jackdaw doctor

## Design decisions worth knowing

- **.NET 8, self-contained.** One binary per platform, no runtime install.
- **The model runs in a separate process** (llama.cpp with the Vulkan backend for AMD).
  This app is only an HTTP client, so swapping models never touches the code.
- **Windows service plus unprivileged clients.** The tray, CLI, and LAN dashboard all
  talk to one elevated core over a named pipe.
- **`changelog.json` is the single source of truth.** `CHANGELOG.md` and the in-app
  changelog are both rendered from it.

## Roadmap

| Phase | Scope |
|---|---|
| 0 | Packaging, changelog pipeline, release pipeline |
| 1 | Core service, IPC, SQLite store, tray, dashboard shell |
| 2 | Local model wiring and the gaming guard (measure FPS before adding features) |
| 3 | Host telemetry, rule engine, alerts |
| 4 | Network telemetry, router integration, LAN discovery |
| 5 | Response actions with approval gates |
| 6 | Remote agents for Pi, NAS, and Linux hosts |
| 7 | The self-extension loop |

## Not to be confused with

There are other projects called Jackdaw. If you arrived here by accident, you may have
wanted the [Bevy level editor](https://github.com/jbuehler23/jackdaw) or the
[Active Directory recon tool](https://github.com/skelsec/jackdaw).

## Licence

MIT.
JACKDAW_EOF

commit "docs: readme, agent schema, and roadmap" \
       "Documents the naming collisions so the shared name is a deliberate choice."

# --------------------------------------------------------------------- ci ----

write .github/workflows/ci.yml <<'JACKDAW_EOF'
name: ci

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Build
        run: dotnet build Jackdaw.slnx -c Release

      - name: Check the changelog is current
        run: |
          dotnet run --project tools/Jackdaw.ChangelogGen -c Release -- --quiet
          if ! git diff --quiet -- changelog.json CHANGELOG.md; then
            echo "::warning::changelog.json or CHANGELOG.md is stale. Run: dotnet run --project tools/Jackdaw.ChangelogGen"
          fi

      - name: Smoke test
        run: |
          dotnet run --project src/Jackdaw.Cli -c Release -- version
          dotnet run --project src/Jackdaw.Cli -c Release -- doctor
JACKDAW_EOF

write .github/workflows/release.yml <<'JACKDAW_EOF'
name: release

on:
  push:
    tags: ["v*"]
  workflow_dispatch:
    inputs:
      version:
        description: Version to release, without the leading v
        required: true

permissions:
  contents: write

jobs:
  build:
    needs: build
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - { rid: win-x64,     os: windows-latest }
          - { rid: win-arm64,   os: windows-latest }
          - { rid: linux-x64,   os: ubuntu-latest }
          - { rid: linux-arm64, os: ubuntu-latest }
          - { rid: osx-arm64,   os: macos-14 }
          - { rid: osx-x64,     os: macos-14 }

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Publish
        shell: bash
        run: |
          dotnet publish src/Jackdaw.Cli \
            -c Release \
            -r ${{ matrix.rid }} \
            --self-contained true \
            -p:PublishSingleFile=true \
            -p:IncludeNativeLibrariesForSelfExtract=true \
            -p:EnableCompressionInSingleFile=true \
            -o out/${{ matrix.rid }}

      - name: Package
        shell: bash
        run: |
          cd out/${{ matrix.rid }}
          rm -f ./*.pdb
          tar -czf "../jackdaw-${{ matrix.rid }}.tar.gz" .
          cd ..
          if command -v sha256sum >/dev/null 2>&1; then
            sha256sum "jackdaw-${{ matrix.rid }}.tar.gz" > "jackdaw-${{ matrix.rid }}.tar.gz.sha256"
          else
            shasum -a 256 "jackdaw-${{ matrix.rid }}.tar.gz" > "jackdaw-${{ matrix.rid }}.tar.gz.sha256"
          fi
          cat "jackdaw-${{ matrix.rid }}.tar.gz.sha256"

      - uses: actions/upload-artifact@v4
        with:
          name: jackdaw-${{ matrix.rid }}
          path: out/jackdaw-${{ matrix.rid }}.tar.gz*

  release:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - uses: actions/download-artifact@v4
        with:
          path: dist
          merge-multiple: true

      - name: Work out the version
        id: v
        run: |
          if [ -n "${{ inputs.version }}" ]; then
            echo "version=${{ inputs.version }}" >> "$GITHUB_OUTPUT"
          else
            echo "version=${GITHUB_REF_NAME#v}" >> "$GITHUB_OUTPUT"
          fi

      - name: Regenerate the changelog for this release
        run: |
          dotnet run --project tools/Jackdaw.ChangelogGen -c Release -- --promote "${{ steps.v.outputs.version }}"

      - name: Extract release notes from the changelog
        run: |
          awk -v ver="v${{ steps.v.outputs.version }}" '
            $0 ~ "^## " ver " " { found=1; next }
            found && /^## / { exit }
            found { print }
          ' CHANGELOG.md > notes.md
          test -s notes.md || echo "See CHANGELOG.md" > notes.md

      # Without this the released section only ever exists inside the release
      # notes, and the next generator run on main silently drops it.
      - name: Commit the released changelog back to main
        run: |
          git config user.name  "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add changelog.json CHANGELOG.md
          if git diff --cached --quiet; then
            echo "nothing to commit"
            exit 0
          fi
          git commit -m "chore: changelog for v${{ steps.v.outputs.version }}"
          git push origin "HEAD:main" \
            || echo "::warning::could not push the changelog to main"

      - name: Publish the release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release create "v${{ steps.v.outputs.version }}" \
            --title "Jackdaw v${{ steps.v.outputs.version }}" \
            --notes-file notes.md \
            dist/jackdaw-*.tar.gz dist/jackdaw-*.tar.gz.sha256
JACKDAW_EOF

commit "feat: release pipeline building six platforms" \
       "Builds self-contained binaries, publishes checksums, and pulls release notes from the changelog."

# ---------------------------------------------------------------- finish up ---

if [ "$RUN_GEN" = 1 ]; then
  if command -v dotnet >/dev/null 2>&1; then
    echo
    echo "Generating the changelog from the commits just made"
    dotnet run --project tools/Jackdaw.ChangelogGen -c Release -- --quiet
    commit "chore: regenerate changelog from the initial commits" \
           "chore keeps this out of its own output so regenerating stays idempotent."
  else
    echo
    echo "note: dotnet not found, skipping changelog generation"
    echo "      install the .NET 8 SDK, then run:"
    echo "      dotnet run --project tools/Jackdaw.ChangelogGen"
  fi
fi

if [ "$DO_PUSH" = 1 ]; then
  echo
  echo "Pushing to origin"
  # Force the exec bit after all commits. On Windows with core.filemode=false a
  # plain chmod does not survive git add.
  git update-index --chmod=+x install.sh 2>/dev/null || true
  branch="$(git rev-parse --abbrev-ref HEAD)"
  git push -u origin "$branch"
fi

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  echo
  echo "Updating repository metadata"
  gh repo edit "$REPO" --description "$DESCRIPTION" --add-topic "$TOPICS" || true
fi

echo
echo "Done."
echo
echo "Next:"
echo "  dotnet run --project src/Jackdaw.Cli -- doctor"
echo "  dotnet run --project src/Jackdaw.Cli -- changelog"
echo
echo "Then cut the first release:"
echo "  git tag v0.1.0 && git push --tags"
