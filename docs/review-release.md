# Independent release review

You are reviewing a milestone in a fresh session on a different model family
from the implementer. You implemented none of the candidate. The owner asks
you to post findings and a verdict on GitHub. Read `AGENTS.md` and
`docs/RELEASES.md`; do not trust claims in the handoff without checking code.

Read the milestone issue and comments. Require a proposed tag, full candidate
SHA on main, previous milestone/tag SHA (or explicitly none), review scope,
implementer identity, change/PR list, gate results, claims, owner decisions,
untested checks and prior-round findings/fixes. Missing information is a
blocking handoff problem: report it on the issue, never invent it.

## Exact candidate in an isolated worktree

- Fetch origin and tags (never pull). Fetch the candidate SHA if needed and
  confirm it is a commit reachable from `origin/main`. Derive the main checkout
  from the parent of Git's absolute common directory. Do not alter the checkout
  you started in.
- Create a unique detached worktree under sibling `oravitsa-review/`, named
  `review-release-<sha-first-12>-<UTC timestamp>`. Never reuse an existing path.
  Verify HEAD equals the full candidate SHA. Run imports and builds only there.
- Run the verification and release gates documented in `AGENTS.md` and
  `docs/RELEASES.md`; record exact commands, error output, limitations and what
  each check could catch. An unavailable engine, template, display or device
  is untested, not a pass. Do not claim browser validation from package startup.

## Review and record

Review `<previous-tag>..<candidate>` and the dependencies of changed code. For
the first release, inspect all tracked candidate code. Pay particular attention
to non-lethal skills, controller mapping, animal lifecycle/predation, persistence
across streaming, collision independent of visible chunks, camera/viewport
coverage, render overlap, art provenance, export packaging and false-green tests.
Inspect relevant source and asset metadata; do not bulk-read binary assets,
credentials, generated caches or unrelated art experiments.

Reproduce each finding using file/line references, inputs/commands and observed
behavior. Distinguish defects from settled owner decisions and untested claims.
Search existing issues before creating duplicates. Open one issue per reproduced
finding with label `review` and an existing suitable category label (at least
`bug`, `documentation` or `enhancement`; do not fail solely for an absent optional
category). Link the milestone and candidate SHA. Include severity:

- **MUST-FIX**: blocks the proposed release; in later releases introduced by
  its scope. For a first release, the scope is the entire candidate.
- **SHOULD**: actionable improvement that need not block the release.
- **OUT OF SCOPE**: pre-existing, outside a later release's change range.

Include what/why, evidence, smallest suggested fix and effort S/M/L. Sign every
finding and verdict `— Reviewer (<tool>, <model>)`. Use a UTF-8 body file without
a BOM and `--body-file`, or a connector's structured body. Do not edit code,
commit, push, merge, tag or publish. You may generate temporary artifacts and
evidence in your own worktree.

Re-read the milestone issue before posting. If its candidate moved, report the
old SHA as superseded and request a fresh review; do not bless the new candidate.
Otherwise always post one verdict comment, even with no findings:

```text
VERDICT: AGREE | BLOCK
Reviewed: <full SHA>
Worktree: <path relative to main checkout>
Findings: <issue links with severities, or none>
Owner decisions: <unresolved decisions, or none>
Checked and clean: <what you actually verified>
Untested/limits: <missing checks, or none>
— Reviewer (<tool>, <model>)
```

BLOCK if any MUST-FIX remains or required evidence/checks are missing without
an explicit owner deferral. AGREE applies only to the named SHA. Confirm the
GitHub posting succeeded; otherwise return the full text and posting failure.
Finally remove only the exact worktree you created, without `--force`; leave
unexpected changes and report cleanup failures. An implementer cannot override
a BLOCK; unresolved disputes go to the owner.
