# crumb-mcp — Technical Architecture

This document explains how `crumb-mcp` is built and how it works internally. For
installation and usage, see the [README](README.md).

## What it is

`crumb-mcp` is a standalone [Model Context Protocol](https://modelcontextprotocol.io)
(MCP) server, packaged as a Ruby gem. It exposes a Crumb deployment history as a set
of LLM-callable **tools**. An MCP client (Claude Code) launches it as a subprocess and
talks to it over stdio; the server in turn makes authenticated HTTP calls to one or
more [Crumb engine](../engine) read APIs and returns the results as text.

```
┌──────────────┐   stdio / JSON-RPC   ┌──────────────┐   HTTPS + Bearer   ┌──────────────┐
│ Claude Code  │ ───────────────────► │  crumb-mcp   │ ─────────────────► │ Crumb engine │
│ (MCP client) │ ◄─────────────────── │ (this gem)   │ ◄───────────────── │ read API     │
└──────────────┘    tool results      └──────────────┘     JSON           └──────────────┘
                                             │
                                             │ git -C <repo> show   (optional, local)
                                             ▼
                                       local checkout
```

The gem is a **client of Crumb, not a part of it.** It holds no deployment data; it
federates over the HTTP read API that each app mounts via the engine. This keeps the
MCP layer thin and lets one developer query many apps (staging, production, several
services) from a single process.

## Process model

The server runs as a short-lived child process of the MCP client. Communication is
JSON-RPC over **stdio**:

- **stdout** carries the JSON-RPC protocol stream. Nothing else may be written there —
  a stray `puts` or a library banner on stdout corrupts the handshake and the client
  reports "failed to connect."
- **stderr** is free for diagnostics.

There is no long-running daemon, no port, and no local state. The client spawns the
process, performs the MCP handshake, lists tools, and invokes them on demand.

## Package layout

```
mcp/
├── exe/
│   └── crumb-mcp                 # executable entrypoint (the gem's bindir)
├── lib/
│   ├── crumb-mcp.rb              # convenience require → crumb/mcp
│   └── crumb/
│       ├── mcp.rb                # top-level require graph
│       └── mcp/
│           ├── version.rb        # Crumb::MCP::VERSION
│           ├── registry.rb       # config file → endpoint resolution
│           ├── api_client.rb     # HTTP client for one endpoint
│           └── tools/
│               ├── recent_deploys.rb
│               ├── deploy_details.rb
│               ├── compare_deploys.rb
│               └── find_deploys_touching.rb
├── crumb-mcp.gemspec
├── README.md / ARCHITECTURE.md / CHANGELOG.md / LICENSE
└── test/
```

The gem name (`crumb-mcp`) differs from the Ruby namespace (`Crumb::MCP`). `lib/crumb-mcp.rb`
exists only so `require "crumb-mcp"` resolves; it delegates to `lib/crumb/mcp.rb`, which
wires up the full require graph.

## The entrypoint — `exe/crumb-mcp`

```ruby
#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "crumb/mcp"

server = MCP::Server.new(
  name:    "crumb",
  version: Crumb::MCP::VERSION,
  tools:   [ RecentDeploysTool, DeployDetailsTool, CompareDeploysTool, FindDeploysTouchingTool ]
)

MCP::Server::Transports::StdioTransport.new(server).open
```

Three things worth noting:

1. **It manipulates `$LOAD_PATH` directly instead of `require "bundler/setup"`.**
   When the gem is installed standalone (`gem install crumb-mcp`), `bundler/setup`
   would look for a `Gemfile` in the *launch* directory — which is the user's Rails
   app, not this gem — and either fail or load the wrong dependency set. Pushing the
   gem's own `lib` onto the load path and relying on RubyGems to resolve the runtime
   dependencies (`mcp`, `faraday`) is what makes it work from anywhere.

2. **Tools are registered as classes, not instances.** Each tool is a class that
   extends `MCP::Tool` and answers `call(...)` at the class level. The `mcp` gem reads
   the declared `tool_name`, `description`, and `input_schema` to advertise the tool
   to the client.

3. **`StdioTransport` owns the loop.** `.open` blocks, reading framed JSON-RPC from
   stdin and writing responses to stdout, dispatching `tools/call` to the matching
   tool class. All the server's behavior lives in the tools.

## Configuration & endpoint resolution — `Registry`

`Registry` reads a single YAML file at `~/.config/crumb/config.yml` and turns endpoint
slugs into connection details. It is the only source of "which apps exist."

```yaml
endpoints:
  my-app-staging:
    base_url: https://staging.your-app.com/crumb
    token_env: CRUMB_READ_TOKEN_STAGING
    repo_path: ~/code/your-app        # optional
```

- The map keys are **slugs** — the identifiers tools accept as the `endpoint` argument.
- `config` is memoized and loaded with `YAML.safe_load_file`; a missing file raises a
  clear error naming the expected path.
- `endpoints` raises if the top-level `endpoints:` key is absent, so a malformed config
  fails loudly rather than silently yielding zero endpoints.
- `endpoint_for(slug)` returns a normalized hash `{ base_url:, token_env:, repo_path: }`,
  expanding `repo_path` to an absolute path. Unknown slugs raise `ArgumentError`.
- `all_slugs` returns every configured slug — this is what powers the "omit endpoint to
  fan out across all apps" behavior in the tools.

**Secrets stay out of the file.** The config stores the *name* of an env var
(`token_env`), not the token itself. The actual read token is read from `ENV` at call
time (see below).

## HTTP layer — `ApiClient`

One `ApiClient` instance corresponds to one endpoint. The factory wires it from the
registry and the environment:

```ruby
ApiClient.for(slug)
#  → Registry.endpoint_for(slug)          # base_url, token_env, repo_path
#  → ENV.fetch(token_env)                 # the actual bearer token (raises if missing)
#  → new(base_url, token, repo_path, slug)
```

Requests go through a memoized Faraday connection with explicit timeouts so a hung or
unreachable endpoint can't block the MCP process indefinitely:

```ruby
OPEN_TIMEOUT = 5      # seconds to establish the connection
READ_TIMEOUT = 15     # seconds to read the response
```

Each `get` sets `Authorization: Bearer <token>` and `Accept: application/json`, requires
HTTP 200, parses the JSON body, and wraps any `Faraday::Error` (timeout, DNS, refused)
in a `Crumb::MCP::ApiClient::Error` that names the slug — so failures are attributable
to a specific endpoint.

**One detail that matters:** URLs are built by string concatenation —
`connection.get("#{@base_url}#{path}")` — *not* with Faraday's base-URL + relative-path
resolution. The engine is mounted under a path prefix (`/crumb`), and Faraday's relative
resolution would discard that prefix. Concatenating the full URL preserves it.

### API surface used

| Method | HTTP call | Returns |
|--------|-----------|---------|
| `recent(limit:)` | `GET /deploys?limit=N` | list of deploy summaries |
| `detail(id)` | `GET /deploys/:id` | one deploy with commits + changed files |
| `touching(prefix, limit:)` | `GET /deploys?touching=<prefix>&limit=N` | deploys that changed files under a prefix |
| `diff(sha)` | local `git -C <repo_path> show <sha> --stat` | git diffstat |

Every API response is tagged with `"endpoint" => @slug` before being returned, so once
results from multiple endpoints are merged, each row still knows where it came from.

`diff` is the one operation that does **not** hit the network: it shells out to `git`
against the optional local `repo_path`. Both the directory and the SHA are passed through
`Shellwords.escape`. If no `repo_path` is configured for the endpoint, it raises rather
than guessing.

## Tools

Each tool is a class extending `::MCP::Tool` that declares its `tool_name`,
`description`, and `input_schema` (JSON Schema), and implements a class-level `call`.
Every `call` returns an `MCP::Tool::Response` wrapping a single `text` block — the
server's output is always human/LLM-readable text, formatted in the tool, never raw
JSON handed back to the model.

| Tool | Required input | Optional input | Behavior |
|------|----------------|----------------|----------|
| `recent_deploys` | — | `endpoint`, `limit` | Lists recent deploys |
| `deploy_details` | `endpoint`, `id` | `include_diff` | Full detail for one deploy |
| `compare_deploys` | `endpoint`, `from_id`, `to_id` | — | Union of commits/files between two deploys |
| `find_deploys_touching` | `path_prefix` | `endpoint`, `limit` | Deploys that changed files under a prefix |

### Fan-out and partial failure

`recent_deploys` and `find_deploys_touching` both follow the same pattern: if `endpoint`
is given, query just that slug; otherwise query `Registry.all_slugs`. Crucially, the
loop **isolates failures per endpoint**:

```ruby
slugs.each do |slug|
  deploys.concat(ApiClient.for(slug).recent(limit: limit))
rescue => e
  errors << "[#{slug}] error: #{e.message}"
end
```

A down or misconfigured endpoint contributes an error line to the bottom of the output
instead of aborting the whole call — so one broken staging server doesn't hide
production's deploys. Merged results are sorted by `finished_at` descending before
formatting.

### Detail and comparison

- `deploy_details` fetches one deploy and formats its header, commit list, and changed
  files. With `include_diff: true` it additionally appends the local `git show --stat`
  output for the deploy's SHA (slow, and requires `repo_path`).
- `compare_deploys` fetches two deploys and presents the **union** of their commits
  (deduped by `sha`) and changed files (deduped by `path`).

### Defensive formatting

Throughout the formatters, SHAs are truncated with `["sha"].to_s[0, 8]` rather than
`["sha"][0, 8]`. The `.to_s` guards against a `nil` SHA (which would otherwise raise
`NoMethodError`), so malformed or partial API rows degrade gracefully instead of
crashing the tool call.

## Require graph

```
exe/crumb-mcp
  └── require "crumb/mcp"          (lib/crumb/mcp.rb)
        ├── require "mcp"          (the upstream MCP framework gem)
        ├── require_relative "mcp/version"
        ├── require_relative "mcp/registry"
        ├── require_relative "mcp/api_client"
        └── require_relative "mcp/tools/*"
```

`api_client.rb` additionally requires `faraday`, `json`, `shellwords`, and `uri`;
`registry.rb` requires `yaml`. These are stdlib except Faraday, which is a declared
runtime dependency.

## Packaging & dependencies

From the gemspec:

- `required_ruby_version >= 3.0`.
- Runtime deps are pinned pessimistically: `mcp ~> 0.8, >= 0.8.0` and `faraday ~> 2.0`.
- `bindir` is `exe`, with `crumb-mcp` as the single executable.
- `metadata` declares `rubygems_mfa_required => "true"` (push requires MFA) plus
  source/homepage/changelog URIs.
- Published to RubyGems.org as `crumb-mcp` (v0.1.0).

### The Ruby-version-manager gotcha

Under asdf/rbenv/rvm, gems are installed **per Ruby version**, and the `crumb-mcp` shim
resolves its Ruby version from the directory it is *launched* in — not from where
`gem install` or `claude mcp add` was run. Claude Code launches the server from the
project you're working in, so the gem must be installed under that project's Ruby
version for the bare `crumb-mcp` command to resolve. See the README's
[Installation](README.md#installation) and [Registering](README.md#registering-with-claude-code)
sections for the install-location rule and the version-pinning options.

## Request lifecycle (end to end)

A representative `recent_deploys` call with no `endpoint`:

1. Claude Code sends a `tools/call` JSON-RPC request over stdin.
2. `StdioTransport` dispatches it to `RecentDeploysTool.call`.
3. The tool asks `Registry.all_slugs` for every configured endpoint.
4. For each slug it builds an `ApiClient` (`Registry.endpoint_for` + `ENV.fetch(token_env)`)
   and calls `recent`, which issues `GET <base_url>/deploys?limit=N` with a bearer token
   and 5s/15s timeouts.
5. Per-endpoint failures are caught and collected as error lines; successful rows are
   tagged with their endpoint and merged.
6. Merged rows are sorted by `finished_at` descending and formatted into a text block;
   any errors are appended.
7. The tool returns an `MCP::Tool::Response`; the transport serializes it back over
   stdout to the client.
