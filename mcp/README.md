# crumb-mcp

A standalone [MCP](https://modelcontextprotocol.io) server that queries one or more
[Crumb](../README.md) endpoints, so an AI assistant (e.g. Claude Code) can answer
questions about your deploys: what shipped, when, by whom, and which files changed.

Each developer runs this locally. It talks to the read API exposed by the
[`crumb` engine](../engine) mounted in your apps, authenticating with a read token.

## Installation

```bash
cd mcp
bundle install
```

The entrypoint is `exe/crumb-mcp`, run over stdio.

## Configuration

Create `~/.config/crumb/config.yml` describing each app endpoint you want to query:

```yaml
endpoints:
  my-app-staging:
    base_url: https://staging.your-app.com/crumb
    token_env: CRUMB_READ_TOKEN_STAGING
    repo_path: ~/code/your-app          # optional, for local git lookups
  my-app-production:
    base_url: https://your-app.com/crumb
    token_env: CRUMB_READ_TOKEN_PRODUCTION
    repo_path: ~/code/your-app
```

- **`base_url`** — the engine's mount URL (the same `/crumb` path the app mounts).
- **`token_env`** — the name of the env var holding this endpoint's read token. The
  server reads the token from the environment, so secrets stay out of the config file.
- **`repo_path`** — optional local checkout, used by tools that inspect git directly.

The map keys (`my-app-staging`, …) are the endpoint **slugs** you pass to the tools;
omit the slug on most tools to fan out across every endpoint.

Mint a token from each app (`bin/rails crumb:tokens:mint OWNER=you@example.com` — see the
[engine README](../engine/README.md#read-access-tokens)) and export it under the matching
`token_env`:

```bash
# ~/.zshrc
export CRUMB_READ_TOKEN_STAGING=...
export CRUMB_READ_TOKEN_PRODUCTION=...
```

## Registering with Claude Code

```bash
claude mcp add crumb -- bash -c "cd /absolute/path/to/crumb/mcp && bundle exec exe/crumb-mcp"
```

Running through `bundle exec` (and the `bash -c "cd … && …"` wrapper) ensures the server
loads with the gem's locked dependencies. Restart Claude Code so the tools register in a
fresh session, then ask things like *"What deployed to my-app-staging today?"*.

## Tools

| Tool | Input | Returns |
|------|-------|---------|
| `recent_deploys` | `endpoint?`, `limit?` | Most recent deploys, across all endpoints or one |
| `deploy_details` | `endpoint`, `id`, `include_diff?` | One deploy with commits and changed files |
| `compare_deploys` | `endpoint`, `from_id`, `to_id` | Union of commits/files between two deploys |
| `find_deploys_touching` | `path_prefix`, `endpoint?`, `limit?` | Deploys that changed files under a path prefix |

## License

[MIT](https://opensource.org/licenses/MIT).
