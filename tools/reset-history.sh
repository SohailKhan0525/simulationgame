#!/usr/bin/env bash
# One-shot migration requested by the repository owner. No network writes until
# every inventoried ref has been checked, then one atomic, leased push.
set -euo pipefail

fail() { printf 'History reset refused: %s\n' "$*" >&2; exit 1; }
[[ $# -eq 1 && $1 =~ ^[0-9a-f]{40}$ ]] || fail 'Pass the exact current main commit SHA.'
expected_main=$1
repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"
inventory=tools/history-reset-refs.tsv
[[ -f $inventory ]] || fail 'The reviewed ref inventory is missing.'
[[ -z $(git status --porcelain) ]] || fail 'The checkout has uncommitted changes.'
[[ $(git rev-parse HEAD) == "$expected_main" ]] || fail 'HEAD differs from the approved main SHA.'

declare -A remote_refs=()
declare -A expected_refs=()
while read -r sha ref extra; do
  [[ -n $sha && -n $ref && -z ${extra:-} ]] || fail 'Unexpected remote inventory format.'
  remote_refs["$ref"]=$sha
done < <(git ls-remote --refs --heads --tags origin)
[[ ${remote_refs[refs/heads/main]:-} == "$expected_main" ]] || fail 'Remote main changed. Inspect it before retrying.'

leases=("--force-with-lease=refs/heads/main:$expected_main")
deletions=()
while read -r sha ref extra; do
  [[ -z ${sha:-} || $sha == \#* ]] && continue
  [[ $sha =~ ^[0-9a-f]{40}$ && -n ${ref:-} && -z ${extra:-} ]] || fail 'Invalid reviewed inventory line.'
  [[ $ref == refs/heads/* || $ref == refs/tags/* ]] || fail "Unapproved ref namespace: $ref"
  git check-ref-format "$ref" >/dev/null || fail "Invalid ref: $ref"
  [[ -z ${expected_refs[$ref]:-} ]] || fail "Duplicate inventory ref: $ref"
  expected_refs["$ref"]=$sha
  [[ $ref == refs/heads/main ]] && continue
  [[ ${remote_refs[$ref]:-} == "$sha" ]] || fail "Ref changed or is already removed: $ref"
  leases+=("--force-with-lease=$ref:$sha")
  deletions+=(":$ref")
done < "$inventory"
[[ -n ${expected_refs[refs/heads/main]:-} ]] || fail 'The original main ref is absent from the inventory.'
[[ ${#deletions[@]} -gt 0 ]] || fail 'No reviewed old refs were supplied.'
for ref in "${!remote_refs[@]}"; do
  [[ -n ${expected_refs[$ref]:-} ]] || fail "A new ref needs review: $ref"
done

# Keep the final reviewed file tree exactly. Omitting -p creates a root commit.
tree_sha=$(git rev-parse 'HEAD^{tree}')
root_sha=$(git -c user.name='github-actions[bot]' \
  -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
  commit-tree "$tree_sha" -m 'feat: launch Qofeno Drive')
[[ $(git rev-list --count "$root_sha") == 1 ]] || fail 'The new commit is not parentless.'
[[ $(git rev-parse "$root_sha^{tree}") == "$tree_sha" ]] || fail 'The new tree differs from the reviewed tree.'

printf 'Replacing main and removing %s reviewed old refs atomically.\n' "${#deletions[@]}"
git push --atomic "${leases[@]}" origin "$root_sha:refs/heads/main" "${deletions[@]}"

# A failure after this point must be inspected, not blindly re-run.
remaining=$(git ls-remote --refs --heads --tags origin)
[[ $remaining == "$root_sha"$'\trefs/heads/main' ]] || fail 'Push returned but remote verification differs; inspect remote state.'
printf 'main now points to parentless commit %s\n' "$root_sha"
if [[ -n ${GITHUB_OUTPUT:-} ]]; then
  printf 'root_sha=%s\n' "$root_sha" >> "$GITHUB_OUTPUT"
fi
if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
  printf 'Fresh main: `%s`\n\nRemoved %s reviewed branch/tag refs. Existing releases and GitHub pull-request refs were not deleted.\n' \
    "$root_sha" "${#deletions[@]}" >> "$GITHUB_STEP_SUMMARY"
fi
