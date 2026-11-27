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
| [`techdocs`](techdocs/action.yml) | Builds a repository's MkDocs docs with a pinned techdocs-cli and MkDocs (no Docker) and publishes them, through Workload Identity Federation, to the GCS bucket a Backstage portal with `techdocs.builder: external` reads. `publish: "false"` only builds. The publishing job grants `id-token: write`. `project-id` (the bucket's project, else the provider's project number) is the Google client's project, which it otherwise asks Resource Manager for and is denied. |

## Reusable workflows

| Workflow | What it does |
|---|---|
| [`ghcr-cleanup`](.github/workflows/ghcr-cleanup.yml) | The retention of a repository's GHCR images: per-commit tags and untagged images older than 14 days go, versioned images stay. Each package gives the calling repository the Admin role (Package settings → Manage Actions access). |
| [`terragrunt`](.github/workflows/terragrunt.yml) | A Terragrunt repository's pipeline: each pull request plans every unit with the read-only identity and keeps the plan files; its merge into `main` applies exactly those plans (a direct push, a stale or expired plan applies nothing), then checks that nothing is left to apply. No key: GitHub's OIDC token, through Workload Identity Federation on GCP, a web identity token file on AWS (`aws-web-identity`), the azurerm provider's own OIDC on Azure. The workflow's header has the contract with the calling repository. |
| [`release`](.github/workflows/release.yml) | A semantic-release release of images a previous job pushed to GHCR, in a job with a GHCR login, buildx and Trivy (the repository's own configuration promotes the images); a stable version then deletes the prereleases it supersedes, from GHCR, GitHub Releases and git. The workflow's header has the contract with the calling repository. |

## Using them

Pin the release, never a branch:

```yaml
- uses: docker/setup-buildx-action@v4
- uses: itauros-com/actions/trivy@v1.2.0
- run: trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$IMAGE"
```

```yaml
commits:
  if: github.event_name == 'pull_request'
  runs-on: ubuntu-24.04
  permissions:
    pull-requests: read
  steps:
    - uses: itauros-com/actions/conventional-commits@v1.2.0
```

Docs built on every pull request and published from `main` (the bucket's IAM lets only `main`
write):

```yaml
docs:
  runs-on: ubuntu-24.04
  permissions:
    contents: read
    id-token: write
  steps:
    - uses: actions/checkout@v7
    - uses: itauros-com/actions/techdocs@v1.3.0
      with:
        entity: default/component/my-service
        bucket: my-techdocs-bucket
        project-id: my-docs-project
        workload-identity-provider: ${{ vars.WIF_PROVIDER }}
        publish: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
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
    uses: itauros-com/actions/.github/workflows/ghcr-cleanup.yml@v1.2.0
    permissions:
      packages: write
    with:
      packages: frontend,backend
      dry-run: ${{ github.event_name == 'workflow_dispatch' && inputs.dry-run }}
```

```yaml
release:
  needs: [version, image]
  if: needs.version.outputs.tag != ''
  permissions:
    contents: write
    packages: write
  uses: itauros-com/actions/.github/workflows/release.yml@v1.2.0
  with:
    packages: frontend
```

A Terragrunt repository's whole pipeline, the units under `live/` and the identity chosen by the
root configuration (`TG_PLAN_ONLY=true` on the pull request's plan):

```yaml
name: terraform

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

permissions: {}

jobs:
  terragrunt:
    uses: itauros-com/actions/.github/workflows/terragrunt.yml@v1.4.0
    permissions:
      contents: read
      id-token: write
      actions: read
      pull-requests: read
    with:
      workload-identity-provider: ${{ vars.WIF_PROVIDER }}
```

On AWS, `aws-web-identity: true` instead of `workload-identity-provider`: the root configuration
sets `AWS_ROLE_ARN` per unit. On Azure, neither: it sets `ARM_USE_OIDC=true` and `ARM_CLIENT_ID`
per unit.

[Checkov](https://www.checkov.io) checks every pull request's plans: the resources as they will
be, whichever module makes them. By default (`checkov: report`) the failed checks go to the
job's summary and the plan passes; `checkov: enforce` fails the plan, and so the apply, while a
check fails; `checkov: off` skips it. A repository skips the checks that do not apply to it in
`.checkov.yaml`, next to its `mise.toml`, each with its reason:

```yaml
skip-check:
  - CKV_AWS_117 # Lambda outside a VPC: the functions reach only AWS APIs
```

A repository with several clouds keeps each one's skips next to its units: a `.checkov.yaml`
in a top folder of `units-directory` (`live/aws/.checkov.yaml`, `live/gcp/.checkov.yaml`) adds
its `skip-check` to the root's; only `skip-check` is read there. The step logs the merged list.

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
repository holds it so: a `v*` tag cannot be updated or deleted (a ruleset), a published
release and its assets cannot change (immutable releases), and `main` changes only through a
squash-merged pull request whose checks passed (a ruleset).

## Changing an action

- Commits and pull request titles: Conventional Commits (`ci.yml` checks them with
  `conventional-commits` itself).
- `ci.yml` runs every action as consumers do, Trivy on amd64 and arm64, and lints the
  workflows with actionlint.
- Actions other than GitHub's (`actions/*`) and Docker's (`docker/*`) are pinned by commit, with
  the version in a comment (`@<sha> # vX.Y.Z`): what runs here runs in every consumer's job,
  with its permissions, and a tag can be moved. Dependabot updates both.
- Trivy's version: `version` and `digest` in [`trivy/action.yml`](trivy/action.yml). The
  digest is the new tag's image index, the same on `public.ecr.aws/aquasecurity/trivy`,
  `ghcr.io/aquasecurity/trivy` and `docker.io/aquasec/trivy`:

  ```bash
  docker buildx imagetools inspect public.ecr.aws/aquasecurity/trivy:<version> --format '{{json .Manifest.Digest}}'
  ```
