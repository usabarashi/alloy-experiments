/**
 * ReviewWorkflow Model
 * --------------------
 * A domain-neutral Alloy 6 specification capturing the techniques explained in Blog.md:
 *   - signatures and signature hierarchies for roles, statuses, and events
 *   - predicates describing guarded transitions with frame conditions
 *   - temporal facts enforcing invariants over traces (always ...)
 *   - run/check commands for bounded model checking
 */
module ReviewWorkflow

open util/ordering[Time]

sig Time {}

abstract sig Status {}
one sig Draft extends Status {}
abstract sig InReview extends Status {}
one sig InReviewPending extends InReview {}
one sig InReviewActive extends InReview {}
one sig Approved extends Status {}
one sig Rejected extends Status {}
one sig Archived extends Status {}

abstract sig EventType {}
one sig Submitted extends EventType {}
one sig ReviewStarted extends EventType {}
one sig ApprovedEvent extends EventType {}
one sig RejectedEvent extends EventType {}
one sig ArchivedEvent extends EventType {}
one sig Idle extends EventType {}

sig Reviewer {}

sig Request {
  var status: one Status,
  var lastEvent: one EventType,
  var assignedTo: lone Reviewer
}

pred submit[r: Request] {
  r.status = Draft
  r.status' = InReviewPending
  r.lastEvent' = Submitted
  some reviewer: Reviewer | r.assignedTo' = reviewer
}

pred startReview[r: Request] {
  r.status = InReviewPending
  r.assignedTo != none
  r.status' = InReviewActive
  r.lastEvent' = ReviewStarted
  r.assignedTo' = r.assignedTo
}

pred approve[r: Request] {
  r.status = InReviewActive
  r.assignedTo != none
  r.status' = Approved
  r.lastEvent' = ApprovedEvent
  r.assignedTo' = r.assignedTo
}

pred reject[r: Request] {
  r.status = InReviewActive
  r.assignedTo != none
  r.status' = Rejected
  r.lastEvent' = RejectedEvent
  r.assignedTo' = r.assignedTo
}

pred archive[r: Request] {
  r.status in Approved + Rejected
  r.status' = Archived
  r.lastEvent' = ArchivedEvent
  r.assignedTo' = none
}

pred stutter {
  all r: Request |
    r.status' = r.status and
    r.lastEvent' = Idle and
    r.assignedTo' = r.assignedTo
}

pred someAction {
  (some r: Request | submit[r]) or
  (some r: Request | startReview[r]) or
  (some r: Request | approve[r]) or
  (some r: Request | reject[r]) or
  (some r: Request | archive[r]) or
  stutter
}

fact init {
  all r: Request |
    r.status = Draft and
    r.lastEvent = Idle and
    no r.assignedTo
}

fact reviewerStaysOnInReview {
  always (
    all r: Request |
      r.status in InReview implies some r.assignedTo
  )
}

fact transitions {
  always someAction
}

assert archivedStopsAssignments {
  always (
    all r: Request |
      r.status = Archived implies no r.assignedTo
  )
}

assert approvalOrRejectionExclusive {
  always (
    all r: Request |
      not (r.status = Approved and r.status = Rejected)
  )
}

run workflowSatisfiable {
  #Request = 1
  #Reviewer = 1
  some r: Request |
    eventually (r.status = Approved) and
    eventually (r.status = Archived)
} for 6 but exactly 1 Request, 1 Reviewer, 6 Time

run workflowReviewedApproval {
  #Request = 1
  #Reviewer = 1
  some r: Request |
    eventually (
      r.lastEvent = Submitted and
      eventually (
        r.lastEvent = ReviewStarted and
        eventually (
          r.lastEvent = ApprovedEvent and
          eventually (r.lastEvent = ArchivedEvent)
        )
      )
    )
} for 6 but exactly 1 Request, 1 Reviewer, 6 Time

run workflowRejectedPath {
  #Request = 1
  #Reviewer = 1
  some r: Request |
    eventually (
      r.lastEvent = Submitted and
      eventually (
        r.lastEvent = ReviewStarted and
        eventually (
          r.lastEvent = RejectedEvent and
          eventually (r.lastEvent = ArchivedEvent)
        )
      )
    )
} for 6 but exactly 1 Request, 1 Reviewer, 6 Time

run workflowIdleDraft {
  #Request = 1
  #Reviewer = 1
  some r: Request |
    eventually (
      r.status = Draft and
      after (r.status = Draft and r.lastEvent = Idle)
    ) and
    eventually (r.status in InReview)
} for 6 but exactly 1 Request, 1 Reviewer, 6 Time

run workflowIdleApproved {
  #Request = 1
  #Reviewer = 1
  some r: Request |
    eventually (
      r.status = Approved and
      after (r.status = Approved and r.lastEvent = Idle)
    ) and
    eventually (r.status = Archived)
} for 6 but exactly 1 Request, 1 Reviewer, 6 Time

run workflowIdleRejected {
  #Request = 1
  #Reviewer = 1
  some r: Request |
    eventually (
      r.status = Rejected and
      after (r.status = Rejected and r.lastEvent = Idle)
    ) and
    eventually (r.status = Archived)
} for 6 but exactly 1 Request, 1 Reviewer, 6 Time

check archivedStopsAssignments for 6 but exactly 1 Request, 1 Reviewer, 6 Time
check approvalOrRejectionExclusive for 6 but exactly 1 Request, 1 Reviewer, 6 Time
run workflowIdleInReview {
  #Request = 1
  #Reviewer = 1
  some r: Request |
    eventually (
      r.status in InReview and
      r.assignedTo != none and
      after (r.status in InReview and r.lastEvent = Idle and r.assignedTo != none)
    ) and
    eventually (
      r.status = InReviewActive and r.lastEvent = ReviewStarted
    )
} for 6 but exactly 1 Request, 1 Reviewer, 6 Time
