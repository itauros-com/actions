# actions

Shared GitHub Actions, for repositories in several GitHub organizations.

Public on purpose: GitHub shares a private repository's actions only within its own
organization, and these serve several. So everything here is generic: no secret, no
credential, nothing about a particular product or client.

## Actions

| Action | What it does |
|---|---|
| [`trivy`](trivy/action.yml) | Puts a pinned Trivy release on the `PATH`, from the Actions cache (on a miss, from the first registry that serves its image), and caches Trivy's vulnerability database for the day. Needs a buildx builder set up first. |

## Using them

Pin the release, never a branch:

```yaml
- uses: docker/setup-buildx-action@v4
- uses: itauros-com/actions/trivy@v1.0.0
- run: trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$IMAGE"
```

Dependabot (`package-ecosystem: github-actions`) opens a pull request in each repository for
every new release: a change here reaches a repository through its own pull request and its
own CI, never all of them at once.

## Releasing

One version for the whole repository, [semver](https://semver.org): a fix is a patch, a new
action or input a minor, a change consumers must follow (an input removed, a behavior
changed) a major. After the merge to `main`, once its CI is green:

```bash
git tag -a v1.0.1 -m "v1.0.1" && git push origin v1.0.1
gh release create v1.0.1 --generate-notes
```

A release is never moved or deleted: consumers and their Dependabot rely on it.

## Changing an action

- Commits and pull request titles: [Conventional Commits](https://www.conventionalcommits.org).
- `ci.yml` runs every action as consumers do, on amd64 and arm64.
- Trivy's version: `version` and `digest` in [`trivy/action.yml`](trivy/action.yml). The
  digest is the new tag's image index, the same on `public.ecr.aws/aquasecurity/trivy`,
  `ghcr.io/aquasecurity/trivy` and `docker.io/aquasec/trivy`:

  ```bash
  docker buildx imagetools inspect public.ecr.aws/aquasecurity/trivy:<version> --format '{{json .Manifest.Digest}}'
  ```
