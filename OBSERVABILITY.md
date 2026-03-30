# Observability

This repository uses OpenTelemetry as the primary observability layer.

The goal is to keep traces, structured logs, and future dashboards understandable across the full request lifecycle while keeping custom telemetry small, consistent, and portable to other repos.

## Principles

1. Use standard semantic conventions first.
2. Add custom attributes only for domain concepts that operators actually need.
3. Prefer the same custom keys across HTTP handlers, queue consumers, agent spans, and logs.
4. Put filterable dimensions on spans.
5. Put durable lifecycle summaries in structured logs.
6. Do not add console-only logging that duplicates structured logs.
7. Do not emit prompts, long reasoning blobs, or other high-volume payloads unless there is a specific operational need.

## Custom Attribute Keys

These custom keys are standardized in code via `TelemetryTags` in [src/MovieTriviaAgent.Core/Observability/TelemetryTags.cs](/Users/billdev/repos/CrankingAI/movie-trivia-agent/src/MovieTriviaAgent.Core/Observability/TelemetryTags.cs).

- `job.id`
  - Stable correlation key for a single async job.
- `job.status`
  - High-level lifecycle state such as `Completed` or `Failed`.
- `movie.requested`
  - The raw or normalized movie title supplied by the caller.
- `movie.rated`
  - The canonical movie title that the system actually rated.
- `movie.score`
  - Final business-domain score for the rated movie.

## Keys We Avoid

- `job.topic`
  - Avoid this key. It is ambiguous and overlaps with `movie.requested`.
- One-off synonyms for the same concept
  - Do not mix keys like `title`, `requestedTitle`, `inputMovie`, or `movie.title` when `movie.requested` and `movie.rated` already cover the domain.

## What Goes On Spans

Spans are the primary place for filterable request dimensions.

Use custom span attributes for:

- `job.id`
- `job.status`
- `movie.requested`
- `movie.rated` when title resolution has completed
- `movie.score` when the score exists

This makes it easy to answer questions such as:

- What happened to this job?
- What movie did the caller ask for?
- What canonical title did the system rate?
- Did a title-resolution mismatch contribute to a surprising result?

## What Goes In Structured Logs

Structured logs should summarize high-value lifecycle moments.

Recommended lifecycle log events:

1. Submit
   - `JobId`
   - `RequestedMovie`
2. Completion
   - `JobId`
   - `RequestedMovie`
   - `RatedMovie`
   - `Score`
3. Failure
   - `JobId`
   - `RequestedMovie`
   - error details

Structured logs should complement traces, not replace them.

## Current Pattern In This Repo

- `SubmitJob`
  - emits `job.id` and `movie.requested`
- `RunJob`
  - emits `job.id`, `job.status`, `movie.requested`, `movie.rated`, and `movie.score`
- `GetJob`
  - emits `job.id`, `job.status`, and when available the final movie and score attributes
- `MovieGreatnessAgent`
  - emits `movie.requested` and `movie.rated` on the top-level agent invoke span

## Reuse In Other Repos

This scheme is intended to carry well into other repos that process user requests and then transform, normalize, enrich, or classify them.

Recommended reuse pattern:

1. Keep `job.*` keys for async lifecycle correlation.
2. Use `{domain}.requested` for caller intent.
3. Use `{domain}.rated`, `{domain}.resolved`, `{domain}.normalized`, or another single standardized counterpart for system interpretation.
4. Keep business outcome values under the domain namespace rather than the job namespace.
5. Put portable keys in a shared constants file so handlers and workers cannot drift.
6. Keep naming stable over time so dashboards and KQL queries survive refactors.

## KQL Examples

Use these as starting points in Application Insights or Log Analytics.

## Recommended Dashboard Fields

For traces, Aspire views, or Application Insights workbook tables, the most useful default columns in this repo are:

1. `timestamp`
2. `operation_Name`
3. `customDimensions["job.id"]`
4. `customDimensions["job.status"]`
5. `customDimensions["movie.requested"]`
6. `customDimensions["movie.rated"]`
7. `customDimensions["movie.score"]`

Recommended views:

1. Intake view: `timestamp`, `job.id`, `movie.requested`
2. Resolution view: `timestamp`, `movie.requested`, `movie.rated`, `movie.score`
3. Failure view: `timestamp`, `job.id`, `job.status`, `movie.requested`, `message`
4. Trace drill-down view: `operation_Name`, `job.id`, `movie.requested`, `movie.rated`, `movie.score`

These fields are intentionally small and stable. They are enough to answer most operational questions without bringing long reasoning text or prompts into dashboards.

### Find runs for a specific requested movie

```kusto
traces
| where customDimensions["movie.requested"] == "Weekend at Bernies"
| project timestamp, message, operation_Name, customDimensions
| order by timestamp desc
```

### See requested vs rated title mismatches

```kusto
traces
| where isnotempty(customDimensions["movie.requested"])
| where isnotempty(customDimensions["movie.rated"])
| where customDimensions["movie.requested"] != customDimensions["movie.rated"]
| project timestamp, operation_Name,
  requested = customDimensions["movie.requested"],
  rated = customDimensions["movie.rated"],
  score = customDimensions["movie.score"],
  jobId = customDimensions["job.id"]
| order by timestamp desc
```

### Find failed jobs by requested movie

```kusto
traces
| where customDimensions["job.status"] == "Failed"
| project timestamp, operation_Name,
  requested = customDimensions["movie.requested"],
  jobId = customDimensions["job.id"],
  message
| order by timestamp desc
```

### Find completion logs with requested, rated, and score

```kusto
traces
| where message has "completed for requested movie"
| project timestamp, message,
  requested = customDimensions["RequestedMovie"],
  rated = customDimensions["RatedMovie"],
  score = customDimensions["Score"]
| order by timestamp desc
```

Example adaptations:

- product scoring service
  - `product.requested`, `product.resolved`
- document pipeline
  - `document.requested`, `document.normalized`
- search workflow
  - `query.requested`, `query.resolved`

## Cost And Safety Notes

- Movie titles are acceptable as span attributes and structured log properties in this repo because they are low-risk business data and useful for debugging.
- Avoid adding high-cardinality free-form text beyond the minimum needed for operational triage.
- If telemetry cost becomes an issue, keep the attributes on top-level lifecycle spans and completion logs only.
