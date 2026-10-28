/// Base URL of the Gratideo auth Worker.
///
/// Override at build time:
///   flutter build apk --dart-define=API_BASE_URL=https://your-worker.workers.dev
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://gratideo-api.im-maxyacademy.workers.dev',
);
