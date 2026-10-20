# Your first cleanup

[README](../README.md) · [Full reference](reference.md) · [Get help](https://github.com/JohanLindvall/crprune/issues/new/choose)

This walkthrough starts with one repository and a dry run. Install crprune using
the [installation instructions](../README.md#install), then check
`crprune --version`.

## 1. Choose and authenticate with a registry

For **Azure Container Registry**, a local Azure CLI login is the simplest starting
point:

```sh
az login
REGISTRY=myregistry
```

Use the registry name or its ACR login server, such as `myregistry.azurecr.io`.
crprune uses Azure's `DefaultAzureCredential`, so environment credentials,
workload identity, and managed identity are also supported. The identity needs
access to the repositories you select. ABAC registries can use literal
repository rules without catalog-listing permission.

For **GitHub Container Registry**, start with a GitHub CLI login:

```sh
gh auth login
gh auth refresh --scopes read:packages,delete:packages
REGISTRY=ghcr.io/myorg
```

Replace `myorg` with the GitHub user or organization owning the packages. A
classic personal access token in `GH_TOKEN` or `GITHUB_TOKEN` also works and takes
precedence over the CLI login. Reading needs `read:packages`; deleting needs
`delete:packages` and admin access to each package. Fine-grained PATs are not
supported by the packages API.

See the [authentication reference](reference.md#authentication) for cloud-specific
Azure settings and GitHub Actions permissions.

## 2. Create a policy for one repository

Save this as `rules.json`, replacing `^my-app$` with your repository's name.
`repo` is a regular expression: anchors match the whole name, and punctuation
such as a literal dot needs escaping (`"^my\\.app$"` in JSON).

```json
[
  {
    "description": "Keep releases; remove old pull-request builds",
    "repo": "^my-app$",
    "tagged": [
      { "tag": "^release-", "keep": true },
      { "tag": "^pr-", "match_older": "14d", "keep": false }
    ]
  }
]
```

Only tags beginning with `pr-` and older than two weeks are candidates for
deletion. Release tags and every other unmatched tag are kept. A manifest
tagged both `pr-123` and `release-1.0` survives because deleting it would also
remove the release tag. This policy leaves untagged images alone.

For GHCR, use the package name without the owner: `^team/my-app$` matches
`ghcr.io/myorg/team/my-app`. Only the first matching repository rule applies;
put specific repositories before broad patterns.

The [bundled policies](reference.md#included-rule-examples) cover untagged images,
keeping the newest build, orphaned manifests, and old repositories. Read each
policy before using it: they apply to all repositories by default.

## 3. Preview the deletions

```sh
crprune -r "$REGISTRY" --progress=plain prune --in rules.json
```

`prune` defaults to a dry run. Look for `Dry-run: deleting manifest` and review the
repository, digest, and tags. Save the log for review if useful:

```sh
crprune -r "$REGISTRY" --progress=plain prune --in rules.json 2> plan.log
```

Recent images (updated within 24 hours), images with no update timestamp, and
locked ACR images are protected. Dependencies and referrers of kept images are
retained too. [Protected manifests](reference.md#protected-manifests) explains the
full policy.

### Protect Kubernetes workloads

From a checkout, collect images from the relevant kubeconfig contexts using
`kubectl` and `jq`:

```sh
scripts/get_pod_images.sh my-context > images.txt &&
  crprune -r "$REGISTRY" --progress=plain prune --in rules.json --running images.txt
```

The inventory includes pods and workload templates, including workloads scaled
to zero and rollout history. Pass multiple context names to include more clusters;
omitting names scans all configured contexts. Running-image protection is
explicit: crprune does not discover clusters on its own.

Keep the `&&`: a failed inventory must stop the cleanup. Add images referenced
only in other clusters, deployment pipelines, or unsupported custom resources
before applying the policy. See [inventory coverage](reference.md#kubernetes-image-inventory).

## 4. Apply the reviewed policy

When the dry run matches your intent, repeat it with `--dry-run=false`:

```sh
crprune -r "$REGISTRY" prune --in rules.json --dry-run=false
```

If the preview used `--running images.txt`, include it in the live command too:

```sh
crprune -r "$REGISTRY" prune --in rules.json --running images.txt --dry-run=false
```

A CLI dry run is not a saved execution plan; the live run evaluates the current
registry and checks each repository again before deletion. Avoid concurrent
pushes or retagging during cleanup. For an interactive preview with a fixed
selection and typed confirmation, use
`crprune -r "$REGISTRY" explore --rules rules.json`.

## See where the space goes

```sh
crprune -r "$REGISTRY" stats --out stats.json
crprune top stats.json -k 10
crprune explore stats.json
```

`unique` counts each blob once across the scan. It is not a promise of reclaimed
storage: other repositories can share the same blobs, and garbage collection
depends on the registry. A `running` count of zero can also mean no inventory was
supplied. Read the [statistics field definitions](reference.md#statistics-alias-stats).

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| `crprune: command not found` | Add `~/.local/bin` or Go's binary directory to `PATH`, or use `./crprune` after `make build`. |
| Azure authentication fails | Run `az login`; check whether environment credentials override the intended identity and whether the Azure cloud is correct. |
| ACR catalog listing is denied | Use literal repository patterns such as `^my-app$`, or grant catalog-listing access. See [ABAC permissions](reference.md#abac-registries-and-scoped-permissions). |
| GHCR reports missing packages or denies deletion | Check owner/package names, token scopes, package admin access, and whether `GH_TOKEN` or `GITHUB_TOKEN` overrides the CLI login. |
| An image was kept unexpectedly | Check the 24-hour grace period, all tags, first-match rule order, locks, `--running`, and dependencies/referrers of kept images. Add `-v` before the subcommand for debug logs. |
| Explorer cannot open a terminal | Run it in an interactive terminal. Use `crprune top stats.json` for noninteractive output or `--progress=plain` for batch commands. |
| A run exits nonzero but wrote statistics or deleted some images | A denied repository or interruption can leave partial results. Read the final summary before retrying. |
| The installer is rate-limited | Supply `GH_TOKEN` or `GITHUB_TOKEN`, or download an archive from [Releases](https://github.com/JohanLindvall/crprune/releases). |

For a bug report, include the version, operating system, registry type, a minimal
rule file, and sanitized logs. [Issue forms](https://github.com/JohanLindvall/crprune/issues/new/choose)
walk you through this; report security issues [privately](../SECURITY.md).
