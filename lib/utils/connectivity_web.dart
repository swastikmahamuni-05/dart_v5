import 'dart:html' as html;

Future<bool> hasInternetConnection() async {
  return html.window.navigator.onLine ?? false;
}
