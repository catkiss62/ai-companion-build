import 'package:ai_companion_localfirst/core/phone/simulated_note_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('note quality accepts a grounded short draft', () {
    const draft = SimulatedNoteDraft(
      title: '窗边的小事',
      body: '今天又想起窗边那束光，原来安静也会留下很具体的形状。',
    );
    expect(
      SimulatedNoteQuality.acceptable(draft, recentBodies: const []),
      isTrue,
    );
  });

  test('note quality rejects templates and near duplicates', () {
    const draft = SimulatedNoteDraft(
      title: '一小段',
      body: '根据以上资料，随手记一下今天发生的事情。',
    );
    expect(
      SimulatedNoteQuality.acceptable(draft, recentBodies: const []),
      isFalse,
    );
    const repeated = SimulatedNoteDraft(
      title: '窗边',
      body: '今天又想起窗边那束光，原来安静也会留下很具体的形状。',
    );
    expect(
      SimulatedNoteQuality.acceptable(
        repeated,
        recentBodies: const ['今天又想起窗边那束光，原来安静也会留下很具体的形状。'],
      ),
      isFalse,
    );
  });
}
