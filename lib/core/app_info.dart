/// What the app calls itself.
abstract final class AppInfo {
  /// The name, in Kurdish letters: دەمەتەقێ ("Damatqe"). It is shown as it is in every
  /// language of the app, in the title, the notifications and the texts.
  static const String name = 'دەمەتەقێ';

  /// The same name in Latin letters, for the places that cannot show Kurdish letters
  /// (file names, a log, the Dart package and Android application ids).
  static const String latinName = 'Damatqe';

  static const String version = '0.2.0';
}
