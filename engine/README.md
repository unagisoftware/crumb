# Crumb (engine)

Mountable Rails engine that records deployments and exposes a small HTTP API. Install it
in the app you deploy with Kamal; the generated Kamal hooks report each deploy to it.

This is one half of [Crumb](../README.md) — the other is the [`crumb-mcp`](../mcp) server
developers run locally to query the data.

## Installation

Add the gem (it lives in the `engine/` subdirectory of the repo):

```ruby
gem "crumb", github: "unagisoftware/crumb", glob: "engine/*.gemspec"
```

```bash
bundle install
```

Mount the engine wherever you want the API to live:

```ruby
# config/routes.rb
mount Crumb::Engine, at: "/crumb"
```

Install the migrations and run them:

```bash
bin/rails crumb:install:migrations
bin/rails db:migrate
```

Run the generator to scaffold the initializer and Kamal hooks:

```bash
bin/rails generate crumb:install
```

This creates:

- `config/initializers/crumb.rb` — sets the ingest secret from `CRUMB_INGEST_SECRET`.
- `.kamal/hooks/crumb-env` — **the one file you edit**: the Crumb API URL per deploy
  destination, and how the ingest secret is resolved.
- `.kamal/hooks/crumb-pre-deploy` / `crumb-post-deploy` — the recording logic (owned by
  Crumb; the generator overwrites these on re-run).
- `.kamal/hooks/pre-deploy` / `post-deploy` — thin wrappers that call the sub-hooks. If
  you already have these hooks, the generator appends the Crumb call instead of
  overwriting them.

It also adds `CRUMB_INGEST_SECRET` to the `env.secret` list in your `config/deploy*.yml`
when it finds a top-level `env.secret` block.

## Configuration

### 1. The ingest secret

`CRUMB_INGEST_SECRET` is a shared secret that authenticates writes from the deploy hooks
to the API. The same value must be available in two places:

- **In the app** (so it can validate incoming writes) — delivered via Kamal as an
  `env.secret`. The initializer reads it:

  ```ruby
  # config/initializers/crumb.rb
  Crumb.configure do |c|
    c.ingest_secret = ENV.fetch("CRUMB_INGEST_SECRET", nil)
  end
  ```

- **In the deploy hook's local environment** (so it can authenticate the POST/PATCH).
  Export it before deploying, or fetch it from your secret manager inside `crumb-env`
  (a Bitwarden-via-Kamal example is included in the generated file).

Generate a value with e.g. `openssl rand -hex 32` and store it in your secret manager.

### 2. The API URLs

Edit `.kamal/hooks/crumb-env` and set the Crumb mount URL for each Kamal destination:

```bash
case "$DEST" in
  production) CRUMB_API_URL="https://your-app.com/crumb" ;;
  staging)    CRUMB_API_URL="https://staging.your-app.com/crumb" ;;
  *) echo "Crumb: no API URL configured for destination '$DEST' — skipping" >&2; exit 0 ;;
esac
```

No destination is assumed: a `kamal deploy` without `-d` falls through to the `*)` branch
and skips recording (non-fatal) rather than guessing.

The hooks never block a deploy. If the secret is missing, the API is unreachable, or the
response is unexpected, they log a notice and exit 0 — except the integrity guards below.

### Integrity guards (production)

`crumb-pre-deploy` aborts a **production** deploy if the working tree is dirty or has
unpushed commits, so the recorded SHA always matches something reachable on the remote.
On other destinations it records the condition in the deploy's metadata instead.

## Read access tokens

Read endpoints (used by `crumb-mcp`) require a per-developer access token. Mint one with:

```bash
bin/rails crumb:tokens:mint OWNER=you@example.com
```

The raw token is printed **once** — only its SHA-256 digest is stored. Hand it to the MCP
config (`token_env`) on the developer's machine. In a Kamal-deployed app, run it on a
host, e.g.:

```bash
kamal app exec --destination staging "bin/rails crumb:tokens:mint OWNER=you@example.com"
```

## HTTP API

Mounted under wherever you put the engine (e.g. `/crumb`):

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `POST` | `/deploys` | ingest secret | Open a deploy record; returns `deploy_id` + `previous_sha` |
| `PATCH` | `/deploys/:id` | ingest secret | Close it with status, commits, changed files |
| `GET` | `/deploys` | read token | Recent deploys (`?limit=`, `?touching=<path prefix>`) |
| `GET` | `/deploys/:id` | read token | One deploy with commits and changed files |

## License

[MIT](https://opensource.org/licenses/MIT).
