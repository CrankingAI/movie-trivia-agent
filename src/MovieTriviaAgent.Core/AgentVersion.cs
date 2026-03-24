using System.Reflection;

namespace MovieTriviaAgent.Core;

public static class AgentVersion
{
    public static string Current { get; } =
        Assembly.GetEntryAssembly()?.GetName().Version?.ToString() ?? "0.0.0";
}
