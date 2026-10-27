import 'package:flutter_test/flutter_test.dart';
import 'package:gratideo/data/settings.dart';
import 'package:gratideo/services/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local account registers, rejects a wrong password, and signs in again', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    final auth = await LocalAuthService.load(settings);

    await auth.register(
      name: 'Test User',
      email: 'TEST@example.com',
      password: 'A-sample-password-123',
    );
    expect(auth.isSignedIn, isTrue);
    expect(auth.email, 'test@example.com');
    expect(settings.name, 'Test User');

    await auth.signOut();
    expect(auth.isSignedIn, isFalse);

    await expectLater(
      auth.signIn(email: 'test@example.com', password: 'wrong-password'),
      throwsA(isA<AuthException>()),
    );
    expect(auth.isSignedIn, isFalse);

    await auth.signIn(
      email: 'test@example.com',
      password: 'A-sample-password-123',
    );
    expect(auth.isSignedIn, isTrue);
  });
}
