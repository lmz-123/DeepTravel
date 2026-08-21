from __future__ import annotations

REVIEW_STATES = {"draft", "in_review", "reviewed", "disputed", "retired"}
TRANSITIONS = {
    "draft": {"in_review", "retired"},
    "in_review": {"reviewed", "disputed", "draft", "retired"},
    "reviewed": {"disputed", "retired"},
    "disputed": {"in_review", "retired"},
    "retired": set(),
}


def can_transition(current: str, target: str) -> bool:
    return target in TRANSITIONS.get(current, set())


def publication_blockers(
    *,
    arc_review_state: str,
    field_audit_state: str,
    claim_states: list[str],
    source_counts: list[int],
    fragment_states: list[str],
    asset_sizes: list[int],
    transcript_matches: list[bool],
) -> list[str]:
    blockers: list[str] = []
    if arc_review_state != "reviewed":
        blockers.append("whole_arc_not_reviewed")
    if field_audit_state != "reviewed":
        blockers.append("field_audit_not_reviewed")
    if any(state != "reviewed" for state in claim_states):
        blockers.append("claim_not_reviewed")
    if any(count < 1 for count in source_counts):
        blockers.append("claim_source_missing")
    if any(state != "reviewed" for state in fragment_states):
        blockers.append("fragment_not_reviewed")
    if any(size <= 0 for size in asset_sizes):
        blockers.append("narration_asset_missing")
    if not all(transcript_matches):
        blockers.append("transcript_version_mismatch")
    return blockers
