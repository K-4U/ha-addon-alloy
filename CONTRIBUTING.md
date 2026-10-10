# Contributing

## How it works

The image is the official `grafana/alloy` image plus `curl`, `jq` and two scripts:

- [`alloy-collector`](alloy_collector/rootfs/usr/local/bin/alloy-collector) is the entrypoint. It:
  1. renders the Alloy config from the add-on options (`/data/options.json`)
  2. validates the config
  3. adds any extra `.alloy` files from the add-on's config folder, if they validate
  4. starts `supervisor-stats`
  5. runs Alloy
- [`supervisor-stats`](alloy_collector/rootfs/usr/local/bin/supervisor-stats) polls the Supervisor's stats API for every container. It writes the stats as Prometheus metrics for the unix exporter's textfile collector.

## Tests

You need Docker and bash (Git Bash works on Windows).

```bash
docker build -t alloy-collector:dev alloy_collector
```

```bash
bash tests/run.sh alloy-collector:dev
```

`tests/run.sh` renders the config for every fixture in [tests/options](tests/options), both with and without host access, and runs `alloy validate` on it. Fixtures named `fail-*.json` must be rejected. It also checks that valid extra config is loaded and invalid extra config is reported.

To see what a fixture renders to:

```bash
docker run --rm -e ALLOY_COLLECTOR_HOSTNAME=dev -e ALLOY_COLLECTOR_HOST_ACCESS=true -v "$PWD/tests/options/everything.json:/data/options.json:ro" --entrypoint bash alloy-collector:dev -c 'alloy-collector check && cat /run/alloy-collector/config/main.alloy'
```

## Development in Home Assistant

The repository has Home Assistant's add-on devcontainer ([.devcontainer.json](.devcontainer.json)). Open the folder in VS Code and choose **Reopen in Container**, then run the task **Start Home Assistant**. Home Assistant with a Supervisor starts on http://localhost:7123, and this add-on shows up under the local apps.

If the Supervisor tries to pull the image from ghcr.io instead of building it locally, comment out `image:` in [config.yaml](alloy_collector/config.yaml) while developing, and don't commit that.

## Checks and releases

Every pull request and push to `main` runs [CI](.github/workflows/ci.yml):

- **Add-on lint**: Home Assistant's add-on linter on `config.yaml`.
- **Config validation**: builds the image and runs `tests/run.sh`. It validates against the Alloy version in the Dockerfile, so it catches an Alloy update that renamed or removed something the add-on uses.
- **Build**: builds the image for every architecture with Home Assistant's builder actions ([build.yml](.github/workflows/build.yml)), without publishing.

Dependabot ([.github/dependabot.yml](.github/dependabot.yml)) checks for a new Alloy image daily and for GitHub Actions updates weekly. [Dependabot auto-merge](.github/workflows/dependabot-auto-merge.yml) turns on auto-merge for every Dependabot PR, so GitHub merges it as soon as the required checks pass. A PR that fails a check stays open for you to look at.

`main` is protected by [.github/rulesets/protect-main.json](.github/rulesets/protect-main.json): changes need a pull request with all checks passing. Import it under **Settings → Rules → Rulesets → New ruleset → Import a ruleset**.

### Automatic releases (Alloy updates)

When a merge to `main` changes the Alloy version in the Dockerfile, [Alloy release](.github/workflows/alloy-release.yml):

1. picks the next add-on version from the size of the Alloy update. An Alloy patch bumps the add-on's patch number, a minor bumps the minor, a major bumps the major.
2. runs the [release workflow](.github/workflows/release.yml) for that version (see below)
3. creates a GitHub release `vX.Y.Z` with the Alloy update in its notes

### Manual releases (everything else)

Publish a GitHub release with a tag like `v1.2.3`, and put the changes in the release notes. The [release workflow](.github/workflows/release.yml) then:

1. runs the lint and config validation checks
2. builds the images for that version and pushes them, with a multi-arch manifest, to `ghcr.io/k-4u/addon-alloy`
3. for non-prerelease versions, sets the version in `config.yaml` on `main` and adds the release notes to `CHANGELOG.md`. Home Assistant reads `config.yaml` from `main`, so it only offers the update after the images exist.

Step 3 needs a deploy key with write access, stored as the repository secret `VERSION_DEPLOY_KEY`. The ruleset lets deploy keys bypass the pull request rule. Without the key, the step is skipped with a warning, and Home Assistant won't see the new version.

The images on ghcr.io must be **public**, or Home Assistant can't pull them. GitHub creates new packages as private: after the first release, open the package under your profile's **Packages**, then **Package settings → Change visibility → Public**.
