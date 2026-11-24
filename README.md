# actions

Shared GitHub Actions and reusable workflows, for repositories in several GitHub
organizations.

Public on purpose: GitHub shares a private repository's actions only within its own
organization, and these serve several. So everything here is generic: no secret, no
credential, nothing about a particular product or client.

## Actions

| Action | What it does |
|---|---|
| [`trivy`](trivy/action.yml) | Puts a pinned Trivy release on the `PATH`, from the Actions cache (on a miss, from the first registry that serves its image), and caches Trivy's vulnerability database for the day. Needs a buildx builder set up first. |
| [`conventional-commits`](conventional-commits/action.yml) | Checks a pull request's title (a squash merge's message) and its commits against [Conventional Commits](https://www.conventionalcommits.org). No checkout: the commits come from GitHub's API, so the job grants `pull-requests: read`. |

## Reusable workflows

| Workflow | What it does |
|---|---|
| [`ghcr-cleanup`](.github/workflows/ghcr-cleanup.yml) | The retention of a repository's GHCR images: per-commit tags and untagged images older than 14 days go, versioned images stay. Each package gives the calling repository the Admin role (Package settings → Manage Actions access). |

## Using them

Pin the release, never a branch:

```yaml
- uses: docker/setup-buildx-action@v4
- uses: itauros-com/actions/trivy@v1.1.0
- run: trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$IMAGE"
```

```yaml
commits:
  if: github.event_name == 'pull_request'
  runs-on: ubuntu-24.04
  permissions:
    pull-requests: read
  steps:
    - uses: itauros-com/actions/conventional-commits@v1.1.0
```

A reusable workflow is a job of its own; the caller schedules it and grants its permissions:

```yaml
on:
  schedule:
    - cron: "30 2 * * *"
  workflow_dispatch:
    inputs:
      dry-run:
        description: Only list what would be deleted
        type: boolean
        default: true

permissions: {}

jobs:
  cleanup:
    uses: itauros-com/actions/.github/workflows/ghcr-cleanup.yml@v1.1.0
    permissions:
      packages: write
    with:
      packages: frontend,backend
      dry-run: ${{ github.event_name == 'workflow_dispatch' && inputs.dry-run }}
```

Dependabot (`package-ecosystem: github-actions`) opens a pull request in each repository for
every new release, reusable workflows included: a change here reaches a repository through
its own pull request and its own CI, never all of them at once.

## Releasing

One version for the whole repository, [semver](https://semver.org): a fix is a patch, a new
action, workflow or input a minor, a change consumers must follow (an input removed, a
behavior changed) a major. After the merge to `main`, once its CI is green:

```bash
git tag -a v1.0.1 -m "v1.0.1" && git push origin v1.0.1
gh release create v1.0.1 --generate-notes
```

A release is never moved or deleted: consumers and their Dependabot rely on it. The
repository's rulesets hold it so: a `v*` tag cannot be updated or deleted, and `main` changes
only through a squash-merged pull request whose checks passed.

## Changing an action

- Commits and pull request titles: Conventional Commits (`ci.yml` checks them with
  `conventional-commits` itself).
- `ci.yml` runs every action as consumers do, Trivy on amd64 and arm64, and lints the
  workflows with actionlint.
- Trivy's version: `version` and `digest` in [`trivy/action.yml`](trivy/action.yml). The
  digest is the new tag's image index, the same on `public.ecr.aws/aquasecurity/trivy`,
  `ghcr.io/aquasecurity/trivy` and `docker.io/aquasec/trivy`:

  ```bash
  docker buildx imagetools inspect public.ecr.aws/aquasecurity/trivy:<version> --format '{{json .Manifest.Digest}}'
  ```
