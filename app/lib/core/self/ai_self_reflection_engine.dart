import '../ai/deepseek_client.dart';
import '../database/app_database.dart';
import '../desire/desire_engine.dart';
import '../storage/secure_config.dart';
import 'dream_engine.dart';

/// Compatibility entry point. Nightly Dream is now the sole reflective writer;
/// the old repeated-pattern collector must not run alongside it.
class AiSelfReflectionEngine {
  AiSelfReflectionEngine({required this.db, required DeepSeekClient client,
    required DesireEngine desire, SecureConfig? secureConfig})
    : secureConfig = secureConfig ?? SecureConfig.instance;
  final AppDatabase db;
  final SecureConfig secureConfig;
  Future<bool> maybeReflect({bool force = false}) =>
      DreamEngine(db, secureConfig: secureConfig).maybeDream(manual: force);
}
