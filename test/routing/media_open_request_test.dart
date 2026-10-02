import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/routing/media_open_request.dart';

void main() {
  test('launch without a path leaves the player idle', () {
    expect(MediaOpenRequest.parseArguments(const <String>[]), isNull);
  });

  test('relative paths with spaces become absolute file URIs', () {
    final request = MediaOpenRequest.parseArguments(const <String>[
      'Videos/My Movie.mkv',
    ], currentDirectory: '/home/user');

    expect(request?.uri, Uri.file('/home/user/Videos/My Movie.mkv').toString());
  });

  test('quoted home-relative paths expand the tilde', () {
    final request = MediaOpenRequest.parseArguments(const <String>[
      '~/Videos/movie.webm',
    ], homeDirectory: '/home/user');

    expect(request?.uri, Uri.file('/home/user/Videos/movie.webm').toString());
  });

  test('more than one path is rejected', () {
    expect(
      () =>
          MediaOpenRequest.parseArguments(const <String>['one.mkv', 'two.mkv']),
      throwsFormatException,
    );
  });
}
