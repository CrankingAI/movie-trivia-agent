using Xunit.Abstractions;

namespace MovieTriviaAgent.Eval;

internal static class EvalOutput
{
    internal static void WriteLine(ITestOutputHelper output, string message)
    {
        output.WriteLine(message);
    }
}