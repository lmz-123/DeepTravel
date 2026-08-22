import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';

void main() {
  test('photo upload state is isolated by fragment', () {
    const first = EvidenceUploadState(
      filePath: '/tmp/first.jpg',
      idempotencyKey: 'first-key',
      phase: EvidenceUploadPhase.queued,
    );
    const second = EvidenceUploadState(
      filePath: '/tmp/second.jpg',
      idempotencyKey: 'second-key',
      phase: EvidenceUploadPhase.uploading,
    );
    const state = ActiveTourState(evidenceUploads: {
      'fragment-1': first,
      'fragment-2': second,
    });

    expect(state.evidenceUploadFor('fragment-1')?.filePath, '/tmp/first.jpg');
    expect(state.evidenceUploadFor('fragment-2')?.filePath, '/tmp/second.jpg');
    expect(state.evidenceUploadFor('fragment-1')?.idempotencyKey,
        isNot(state.evidenceUploadFor('fragment-2')?.idempotencyKey));
  });

  test('accepted upload keeps its local preview and stable retry key', () {
    const pending = EvidenceUploadState(
      filePath: '/tmp/clue.jpg',
      idempotencyKey: 'stable-key',
      phase: EvidenceUploadPhase.queued,
    );
    final accepted = pending.copyWith(
      phase: EvidenceUploadPhase.accepted,
      evidenceId: 'evidence-1',
    );

    expect(accepted.filePath, pending.filePath);
    expect(accepted.idempotencyKey, pending.idempotencyKey);
    expect(accepted.evidenceId, 'evidence-1');
  });
}
