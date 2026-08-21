from app.infrastructure.persistence.fragment_seed import ARC_ID


def test_claim_traceability_and_publication_gate(app):
    service = app.extensions["services"]["historical_content"]
    trace = service.claim_traceability("claim-331")
    assert trace["certainty"] == "documented"
    assert trace["sources"]
    report = service.publication_report(ARC_ID)
    assert report["publication_ready"] is False
    assert "whole_arc_not_reviewed" in report["blockers"]
    assert "field_audit_not_reviewed" in report["blockers"]


def test_review_transition_is_audited(app):
    service = app.extensions["services"]["historical_content"]
    service.transition_claim("claim-331", "reviewed", "test-editor")
    trace = service.claim_traceability("claim-331")
    assert trace["review_state"] == "reviewed"
