#!/usr/bin/env bash
# Post the evidence comment on a factory pull request: the configured checks, before/after
# screenshots, and the after video. Media is uploaded with `gh pr comment --attach` when the token
# allows it (user tokens do). The Actions token doesn't ("unsupported authentication type"), so in
# workflows the media is committed to the `factory-evidence` branch and linked from the comment.
# Env: GH_TOKEN, PR, SHA, OUT (holds checks.md and media/), CHECKS (pass|fail), MEDIA_OUTCOME (step outcome), RUN_URL
set -euo pipefail

media="$OUT/media"
body="$OUT/evidence-comment.md"
short="${SHA:0:7}"
mkdir -p "$media"

{
  echo "<!-- factory:evidence sha=$SHA -->"
  echo "## Evidence for $short"
  echo
  echo "### Checks"
  echo
  if [ "$CHECKS" = pass ]; then echo "All configured checks passed."; else echo "**Some configured checks failed.**"; fi
  echo
  cat "$OUT/checks.md"
  echo

  shopt -s nullglob
  afters=("$media"/after-*.png)
  if [ "${#afters[@]}" -gt 0 ]; then
    echo "### Screenshots"
    echo
    echo "| Page | Before | After |"
    echo "|---|---|---|"
    for after in "${afters[@]}"; do
      name=$(basename "$after" .png)
      page=${name#after-}
      before="before-$page.png"
      if [ -f "$media/$before" ]; then
        echo "| \`$page\` | ![before $page](./$before) | ![after $page](./$name.png) |"
      else
        echo "| \`$page\` | (no before) | ![after $page](./$name.png) |"
      fi
    done
    echo
    [ -f "$media/after.webm" ] && { echo "### Video"; echo; echo "A walk through the changed pages is attached below."; echo; }
  elif [ "${MEDIA_OUTCOME:-}" = failure ]; then
    echo "Screenshots were configured but failed to capture. See the run log."
    echo
  fi
  echo "<sub>Factory evidence station. [Run log]($RUN_URL)</sub>"
} > "$body"

files=()
for f in "$media"/*.png "$media"/*.webm; do
  if [ -e "$f" ]; then files+=("./$(basename "$f")"); fi
done

if [ "${#files[@]}" -eq 0 ]; then
  gh pr comment "$PR" --repo "$GITHUB_REPOSITORY" --body-file "$body"
  exit 0
fi

attach=()
for f in "${files[@]}"; do attach+=(--attach "$f"); done
if (cd "$media" && gh pr comment "$PR" --repo "$GITHUB_REPOSITORY" --body-file "$body" "${attach[@]}"); then
  exit 0
fi

echo "gh --attach isn't available with this token; publishing the media to the factory-evidence branch."
dir="pr-$PR/$short"
work="$(mktemp -d)"
remote="https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
if git clone --quiet --depth 1 --branch factory-evidence "$remote" "$work" 2>/dev/null; then
  :
else
  git -C "$work" init --quiet
  git -C "$work" checkout --quiet --orphan factory-evidence
  git -C "$work" remote add origin "$remote"
fi
mkdir -p "$work/$dir"
cp "$media"/*.png "$work/$dir/" 2>/dev/null || true
cp "$media"/*.webm "$work/$dir/" 2>/dev/null || true
git -C "$work" add -A
git -C "$work" -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit --quiet -m "Evidence for #$PR at $short"
git -C "$work" push --quiet origin factory-evidence

base="https://github.com/$GITHUB_REPOSITORY/blob/factory-evidence/$dir"
sed -i -E "s#\(\./([^)]+)\)#($base/\1?raw=true)#g" "$body"
if [ -f "$media/after.webm" ]; then
  printf '\n[after.webm](%s/after.webm)\n' "$base" >> "$body"
fi
gh pr comment "$PR" --repo "$GITHUB_REPOSITORY" --body-file "$body"
