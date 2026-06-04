# crumb-mcp

A standalone [MCP](https://modelcontextprotocol.io) server that queries one or more
[Crumb](../README.md) endpoints, so an AI assistant (e.g. Claude Code) can answer
questions about your deploys: what shipped, when, by whom, and which files changed.

Each developer runs this locally. It talks to the read API exposed by the
[`crumb` engine](../engine) mounted in your apps, authenticating with a read token.

## Installation

Install the gem from RubyGems — no clone needed:

```bash
gem install crumb-mcp
```

The entrypoint is `crumb-mcp`, run over stdio.

> **Using a Ruby version manager (asdf, rbenv, rvm)?** Gems are installed *per Ruby
> version*, and the `crumb-mcp` shim resolves the Ruby version from the directory it's
> launched in. Claude Code launches the server from the project you're working in, so
> **run `gem install crumb-mcp` from inside the project directory you plan to use Crumb
> from** (e.g. `cd ~/code/your-app && gem install crumb-mcp`). That installs the gem
> under the same Ruby version Claude will resolve at launch, so the bare `crumb-mcp`
> command connects. If you bump that project's Ruby version later, re-run the install.
> To use Crumb from several projects on different Ruby versions, install it under each
> (or see [Registering with Claude Code](#registering-with-claude-code) for pinning the
> version explicitly).

> **Working on the gem itself?** Clone the repo and `cd mcp && bundle install`; the
> entrypoint is then `bundle exec exe/crumb-mcp`.

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

If you ran `gem install crumb-mcp`, register the executable directly:

```bash
claude mcp add crumb -- crumb-mcp
```

Or skip the install step entirely and let `gem exec` fetch and run the gem on demand
(Ruby 3.4+ / RubyGems 3.5+):

```bash
claude mcp add crumb -- gem exec crumb-mcp
```

Restart Claude Code so the tools register in a fresh session, then ask things like
*"What deployed to my-app-staging today?"*.

> **Ruby version managers — pinning the version:** if the bare `crumb-mcp` command fails
> to connect, it's almost always because Claude launched it from a project whose Ruby
> version doesn't have the gem installed (see [Installation](#installation)). Either
> install the gem under that version, or pin the version in the registration so it no
> longer depends on the launch directory:
>
> ```bash
> # pin via env (asdf)
> claude mcp add crumb --env ASDF_RUBY_VERSION=3.4.4 -- crumb-mcp
> # or point at the absolute executable for a known-good Ruby
> claude mcp add crumb -- "$(asdf where ruby 3.4.4)/bin/crumb-mcp"
> ```

> **From a local checkout** (gem development): point the command at `bundle exec`:
> `claude mcp add crumb -- bash -c "cd /absolute/path/to/crumb/mcp && bundle exec exe/crumb-mcp"`

## Tools

| Tool | Input | Returns |
|------|-------|---------|
| `recent_deploys` | `endpoint?`, `limit?` | Most recent deploys, across all endpoints or one |
| `deploy_details` | `endpoint`, `id`, `include_diff?` | One deploy with commits and changed files |
| `compare_deploys` | `endpoint`, `from_id`, `to_id` | Union of commits/files between two deploys |
| `find_deploys_touching` | `path_prefix`, `endpoint?`, `limit?` | Deploys that changed files under a path prefix |

## License

[MIT](https://opensource.org/licenses/MIT).
