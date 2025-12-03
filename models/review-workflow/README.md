
## Review Workflow Model

`model.als` describes the following specification for a neutral review process.

### Domain Structure
- **Status lattice**: `Draft` → `InReviewPending` → `InReviewActive` → either `Approved` or `Rejected`, finishing in `Archived`. Requests always inhabit exactly one status.
- **Event kinds**: `Submitted`, `ReviewStarted`, `ApprovedEvent`, `RejectedEvent`, `ArchivedEvent`, `Idle` capture the most recent action; `Idle` is reserved for `stutter`.
- **Actors**: `Reviewer` abstracts individuals or teams that can own a request while it is under review.
- **Request record**: Each request stores its current status, latest event, and optional assignee.

### Behavioral Rules
- **submit**: Moves a draft request into `InReviewPending` and assigns a reviewer.
- **startReview**: Keeps the assignee and shifts the request from `InReviewPending` to `InReviewActive`.
- **approve / reject**: Require an assignee and transition an `InReviewActive` request into `Approved` or `Rejected` while keeping ownership.
- **archive**: Applies to `Approved` or `Rejected` requests and clears `assignedTo` when moving into `Archived`.
- **stutter**: No-op that forces `lastEvent = Idle`, letting traces include idle ticks between impactful transitions.
- **someAction fact**: Every time step must satisfy exactly one of the above predicates (including `stutter`), so the solver only explores valid behaviors and prevents dead traces.

### Invariants
1. **init**: Initially every request is `Draft`, `Idle`, and unassigned.
2. **reviewerStaysOnInReview**: `InReview` states always carry an assignee.
3. **transitions**: Each time step applies one allowed transition, guaranteeing progress (possibly via `stutter`).

## Verification

### Quick Start (Makefile)

```bash
# Run all assertion checks and satisfiability tests
make test

# Generate example traces (markdown)
make trace

# Generate state transition diagram (SVG)
make diagram

# Show available commands
make help

# Clean generated files
make clean
```

**Generated files:**
- `make trace`   → `traces.md`
- `make diagram` → `diagram.dot`, `diagram.svg`
