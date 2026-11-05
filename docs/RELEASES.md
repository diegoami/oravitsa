# Milestone releases

## Current release

[Oravitsa v0.3.0-alpha.2](https://github.com/diegoami/oravitsa/releases/tag/v0.3.0-alpha.2) is published as a
GitHub prerelease, with Windows, Linux and Web ZIPs, a manifest and checksums.

The annotated tag points to exactly
`b4fdf981d7a14c25ed6a570a49b69911ebc5767a`.
[Round 3 independently returned AGREE](https://github.com/diegoami/oravitsa/issues/115#issuecomment-6662634244);
the reviewer confirmed #124/#125 fixed, with no new findings.

The owner explicitly [deferred the remaining manual checks for this alpha](https://github.com/diegoami/oravitsa/issues/115#issuecomment-6663947439):
browser play/performance and Web resizing/phone layouts, physical
controller/touchscreen use, listening/audio quality, and paced final-package
play. Those checks remain **untested, not passed**. This is an alpha-only
deferral; independent review was not waived.

[Completed milestone #115](https://github.com/diegoami/oravitsa/issues/115)
records the tag object, clean tag-build evidence, final published hashes,
review verdicts and owner authorizations. All five uploaded asset sizes and
server-computed SHA-256 digests were verified before and after publication.
The first tag-build import crashed natively; its log was retained and the
unchanged-source retry passed the complete gates before any upload.

The previously pending review and publication decisions are complete. No
website deployment was performed. Closure of reviewer findings remains the
owner's decision.

This publication record is documentation-only on `docs/round3-review-next`,
separate from the immutable published tag. Its local copies in the opening
checkout are intentional release-status reminders. Preserve them, check the
actual checkout SHA before new work, and do not substitute the reminder
branch's HEAD for the released source. Update this section for future releases.

A milestone is a release: an annotated `vX.Y.Z` tag on `main`, at exactly the
reviewed commit from which its artifacts are built. Ordinary PRs, documentation
changes and accumulated commits do not trigger a milestone automatically.
There are no existing release tags at adoption. The owner names the first
version; do not invent a previous milestone or tag historical commits as verified.

## Prepare the candidate

1. The owner calls a milestone, or agrees to the implementer's proposal. Any
   version declaration and release-note changes land first through ordinary PRs.
2. Fetch `origin/main` and tags. Record the candidate's **full SHA**, the last
   stable milestone tag and its SHA, the review round, and every merged PR and
   direct commit since it. For the first release, record `Previous: none` and
   review the **entire tracked repository at the candidate**, not just the
   latest PR or a made-up baseline.
3. From a clean detached worktree at that SHA, run the Python runner tests,
   `tools/verify.py`, Web/Linux exports and packaged native startup. Verify the
   final candidate CI run. Read logs for errors, not only process exit codes.
   Record exact commands, versions, results, artifact paths and SHA-256 hashes.
4. Open `Milestone vX.Y.Z` using the milestone issue template. Include the
   implementer tool/model, changes, claims with `file:line` references, settled
   owner decisions and untested checks. Do not describe the implementer's own
   tests as an independent review. Ensure `milestone` and `review` labels exist
   before relying on them; create missing labels only when preparing a release.

## Independent review

The owner starts a **fresh session**, on a different model family that
implemented none of the candidate. Any tool may follow
`docs/review-release.md`. OpenCode can use:

```sh
opencode run -m <provider/model> --command review-release <milestone-issue>
```

In its TUI use `/new`, choose the model with `/models`, then
`/review-release <milestone-issue>`. No wrapper pins a model. Do not start this
review in the implementing session. The reviewer creates its own detached
worktree, reproduces findings, opens finding issues and posts one
`VERDICT: AGREE` or `VERDICT: BLOCK` comment on the milestone issue, naming the
exact reviewed SHA. An empty review still needs a recorded verdict.

The tag waits for review. On BLOCK, reproduce and fix confirmed MUST-FIX
findings in ordinary PRs, or give the owner the disputed evidence. Update the
candidate SHA, rerun gates there and record the fix PRs and prior verdict.
Prepare a fresh re-review handoff without waiting to be asked; the owner starts
the reviewer. After three rounds without AGREE, the owner decides. Work outside
the milestone can continue on branches; it is not silently added to the frozen
candidate. Any candidate change invalidates the old verdict for tagging.

## Before tagging and publishing

- Try a packaged desktop build and the **exported Web game in a real browser**,
  including resizing/phone layouts, motion behind trees, water/bridge boundaries,
  well/cottage access, food collection and controller skill selection/casting.
  Run controller/device checks where available. Headless tests do not replace
  visual, audio, input or device checks; mark missing checks untested and obtain
  the owner's explicit deferral before tagging.
- After AGREE and the checks above, create an annotated tag on **exactly the
  reviewed SHA** when the owner authorizes the release. Build from a clean
  checkout of that tag, smoke the packages and record hashes in the release.
  Publishing artifacts, deploying a website and creating a GitHub release wait
  for the owner's explicit instruction. A merge to main is not permission to
  publish or tag.
- The owner may explicitly waive the review. Record `tagged without review
  (owner)` and the reason on the issue; do not manufacture an AGREE verdict.
