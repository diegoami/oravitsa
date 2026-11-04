# Milestone releases

## Next action: round-3 release review

The owner deferred this review to the next session. Surface it first when the
repository is opened again, unless the owner changes the priority. Do not start
the review in the implementing session.

Use a **fresh session on a model family other than GPT or Claude**: both
families implemented parts of this candidate. The owner chooses and starts
the independent reviewer.

Copy this prompt:

```text
Independently review Oravitsa release milestone #115, round 3:
https://github.com/diegoami/oravitsa/issues/115

Repository: C:\Users\diego\projects\oravitsa
Proposed release: v0.3.0-alpha.2
Exact candidate: b4fdf981d7a14c25ed6a570a49b69911ebc5767a
Previous milestone: v0.3.0-alpha.1
Previous commit: 58c23f61b96fff082abed2e919e5cdf6f3c74ed0

Read AGENTS.md, docs/RELEASES.md, docs/review-release.md and milestone #115
with all comments. Confirm that the issue still names this exact candidate.
Use the required fresh detached worktree; preserve existing checkouts.

Review the complete release range and dependencies, including the earlier
findings and the #124/#125 fixes in merged PR #126. Reproduce findings,
search for duplicates, and post an exact-SHA VERDICT: AGREE or BLOCK on #115,
signed with your tool/model. Verify claims independently; implementer tests
are evidence, not your own review.

Browser/device/listening/paced-play checks have no owner deferral. Record
untested checks honestly and apply the release-review policy.

Do not edit project source, commit, push, merge, tag, publish or deploy.
```

Milestone #115 is the canonical record of gate results, artifacts, hashes,
prior verdicts and remaining checks. Round 2 blocked the previous candidate;
PR #126 contains implementation fixes, not a replacement review verdict.
The owner approved merging that PR, not waiving review or manual checks.
No tag or release has been published.

This reminder is documentation-only on `docs/round3-review-next`, separate
from the frozen candidate. Its local copies in the opening checkout are
intentional next-session reminders; preserve them. Do not substitute the
reminder branch's HEAD for the candidate or add it to the frozen review scope.
After the review or an owner decision, update/remove this block and its
README/AGENTS pointers so the next action stays current.

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
