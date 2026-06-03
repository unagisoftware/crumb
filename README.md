# Crumb

Deployment observability for Kamal-deployed Rails apps. Crumb records every deploy —
who shipped what commits, which files changed, success/failure, rollbacks — and lets
you query that history (including from an AI assistant) instead of spelunking through
git logs and CI dashboards.

The repo ships two independent gems:

| Gem | Path | Who installs it | What it is |
|-----|------|-----------------|------------|
| **`crumb`** | [`engine/`](engine) | The deployed app | A mountable Rails engine: stores deploy records and exposes a small write/read API. Kamal hooks feed it on each deploy. |
| **`crumb-mcp`** | [`mcp/`](mcp) | Each developer, locally | A standalone [MCP](https://modelcontextprotocol.io) server that queries one or more app endpoints, so an AI assistant can answer "what deployed to staging today?" |

## How it fits together

```
kamal deploy ──► .kamal/hooks/pre-deploy ──┐
                 .kamal/hooks/post-deploy ──┤ POST/PATCH (ingest secret)
                                            ▼
                            crumb engine  (mounted at /crumb in the app)
                                            ▲
                                            │ GET (read token)
crumb-mcp ◄── Claude Code / MCP client ─────┘
```

- The **engine** owns the data and the HTTP API. Writes are authenticated with a shared
  ingest secret; reads with per-developer access tokens.
- The **MCP server** is a thin client over the read API, fanning out across the
  endpoints you configure locally.

## Getting started

1. Install the engine in your app — see [`engine/README.md`](engine/README.md).
2. Install the MCP server locally — see [`mcp/README.md`](mcp/README.md).

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
