import 'package:ai_companion_localfirst/core/diagnostics/attachment_pipeline_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('attachment size and duration diagnostics use coarse buckets', () {
    expect(
      AttachmentPipelineTelemetry.durationBucket(
        const Duration(milliseconds: 8500),
      ),
      '8_19s',
    );
    expect(AttachmentPipelineTelemetry.byteBucket(12 * 1024 * 1024), '5_15mb');
    expect(AttachmentPipelineTelemetry.pixelBucket(3874, 5808), '20mp_plus');
  });

  test('raw error text is reduced to a fixed category', () {
    const secretPath = '/private/user/photo-name.jpg';
    final category = AttachmentPipelineTelemetry.errorCategory(
      'FileSystemException: $secretPath',
    );
    expect(category, 'file_io');
    expect(category, isNot(contains('photo-name')));
  });

  test('ANR correlation is temporal evidence and never claims causality', () {
    final correlation = AttachmentPipelineTelemetry.correlateHistoricalExit(
      {
        'recent': [
          {
            'stage': 'prepare',
            'outcome': 'started',
            'at': 100000,
          },
        ],
      },
      historicalExitAt: 145000,
      historicalExitReason: 'REASON_ANR',
    );
    expect(correlation['possibleRecentAttachmentStage'], isTrue);
    expect(correlation['precedingStage'], 'prepare');
    expect(correlation['causalityEstablished'], isFalse);
    expect(correlation['pathsOrContentsIncluded'], isFalse);
  });
}
