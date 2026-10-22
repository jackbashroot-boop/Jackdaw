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
