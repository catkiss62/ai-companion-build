import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>FlutterSecureStorage.setMockInitialValues({}));
  test('independent work connection persists and invalid edits preserve saved pair',() async {
    final secure=SecureConfig.forTesting(const FlutterSecureStorage());
    await secure.writeWorkConfiguration(independent:true,apiKey:'fixture',endpoint:'https://work.test/v1/chat/completions');
    for(final edit in [('', 'https://work.test/v1/chat/completions'),('fixture','work.test')]) {
      await expectLater(secure.writeWorkConfiguration(independent:true,apiKey:edit.$1,endpoint:edit.$2),throwsA(isA<FormatException>()));
    }
    final reopened=SecureConfig.forTesting(const FlutterSecureStorage());
    final config=await reopened.readWorkConfiguration();
    expect(config['mode'],'independent');expect(config['key'],'fixture');
    expect(config['endpoint'],'https://work.test/v1/chat/completions');
  });
}
