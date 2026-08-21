# Release Checklist

This is the step-by-step process for cutting a new Sharmory release. Follow the steps in order.

---

## 1. Decide the Version Number

Sharmory uses [Semantic Versioning](https://semver.org/):

| Change type | Version bump |
|---|---|
| Bug fixes, docs, tests | Patch: `1.0.0` → `1.0.1` |
| New functions, backwards-compatible behavior changes | Minor: `1.0.0` → `1.1.0` |
| Breaking changes (function renamed/removed, argument order changed) | Major: `1.0.0` → `2.0.0` |

---

## 2. Ensure Tests Pass

Run the full test suite on all three shells before touching any version files:

```bash
./test-sharmory.zsh && bash test-sharmory.bash && pwsh ./test-sharmory.ps1
```

All three must exit `0`. Do not proceed if any test fails.

---

## 3. Bump Version in All Three Function Files

Update the version constant in each file. All three must be bumped to the same version in the same commit.

**`functions.zsh`** (line ~54):
```zsh
typeset -g SHARMORY_VERSION="x.y.z"
```

**`functions.bash`** (line ~61):
```bash
SHARMORY_VERSION="x.y.z"
```

**`functions.ps1`** (line ~16):
```powershell
$script:SharmoryVersion = "x.y.z"
```

---

## 4. Bump Version in Package Files

**`package.json`** (npm):
```json
{
  "version": "x.y.z"
}
```

**`pyproject.toml`** (PyPI):
```toml
[project]
version = "x.y.z"
```

---

## 5. Commit and Tag

```bash
git add functions.zsh functions.bash functions.ps1 package.json pyproject.toml
git commit -m "chore: bump version to x.y.z"
git tag -a "vx.y.z" -m "Release vx.y.z"
git push origin main --tags
```

---

## 6. Create a GitHub Release

1. Go to **Releases → Draft a new release** on GitHub.
2. Select the tag `vx.y.z` you just pushed.
3. Set the title to `v x.y.z`.
4. Write release notes summarizing what changed:
   - New functions added (one line each)
   - Bug fixes
   - Breaking changes (prominently, at the top)
5. Attach no extra assets — the GitHub release page automatically includes source zip/tarball.
6. Publish.

> The GitHub release tag is what `sharmory-doctor` checks against when comparing local vs remote version.

---

## 7. Publish to npm

```bash
npm publish
```

> Requires being logged in with `npm login` and having publish access to the `sharmory` package.

---

## 8. Publish to PyPI

```bash
pip install hatch
hatch build
hatch publish
```

> Requires a PyPI API token configured in `~/.pypi/config` or as `HATCH_INDEX_AUTH`.

---

## 9. Update the Homebrew Tap

The Homebrew formula is in a separate tap repository (`hariharen9/homebrew-tap`). Update the `sharmory.rb` formula there:

1. Calculate the SHA256 of the new release tarball:
   ```bash
   curl -sL https://github.com/hariharen9/sharmory/archive/refs/tags/vx.y.z.tar.gz | shasum -a 256
   ```
2. In `packaging/homebrew/sharmory.rb`, update:
   - `version "x.y.z"`
   - `url "https://github.com/hariharen9/sharmory/archive/refs/tags/vx.y.z.tar.gz"`
   - `sha256 "..."`
3. Copy the updated formula to the tap repo and push.

---

## 10. Update the Scoop Bucket

The Scoop manifest is in a separate bucket repository (`hariharen9/scoop-bucket`). Update `packaging/scoop/sharmory.json`:

1. Calculate the SHA256 of the new `functions.ps1` from the release:
   ```powershell
   (Invoke-WebRequest "https://github.com/hariharen9/sharmory/releases/download/vx.y.z/functions.ps1").Content |
     Out-File -Encoding utf8 /tmp/functions.ps1
   Get-FileHash /tmp/functions.ps1 -Algorithm SHA256
   ```
2. Update the manifest with the new version, URL, and hash.
3. Copy to the bucket repo and push.

---

## 11. Verify the Release

After all packages are published, verify end-to-end:

```bash
# Fresh install test (Zsh/Bash)
curl -fsSL https://raw.githubusercontent.com/hariharen9/sharmory/main/install.sh | bash
sharmory doctor

# npm
npm install -g sharmory@x.y.z
sharmory-install
sharmory doctor

# pip
pip install sharmory==x.y.z
sharmory-install
```

Check that `sharmory doctor` reports the local version as up to date with the new release tag.

---

## Post-Release

- Close any GitHub issues that were resolved by this release.
- Update `docs/function-reference.md` if new functions were added (the tables should reflect the new catalog).
- Announce on any relevant channels.

---

## Quick Reference

```
[ ] All tests pass (Zsh + Bash + PowerShell)
[ ] SHARMORY_VERSION bumped in functions.zsh, functions.bash, functions.ps1
[ ] version bumped in package.json and pyproject.toml
[ ] Commit and tag pushed (vx.y.z)
[ ] GitHub Release created with release notes
[ ] npm publish
[ ] PyPI hatch publish
[ ] Homebrew tap formula updated
[ ] Scoop bucket manifest updated
[ ] End-to-end install verified
[ ] Relevant GitHub issues closed
```
