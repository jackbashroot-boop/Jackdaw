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
