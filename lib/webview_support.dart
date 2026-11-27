import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

enum ExternalUriAction { navigate, launchExternal, ignore }

ExternalUriAction externalUriAction(Uri? uri) {
  if (uri == null) return ExternalUriAction.ignore;
  final String scheme = uri.scheme.toLowerCase();
  if (<String>{'http', 'https', 'about', 'data', 'blob'}.contains(scheme)) {
    return ExternalUriAction.navigate;
  }
  if (scheme == 'javascript' || scheme.isEmpty) {
    return ExternalUriAction.ignore;
  }
  return ExternalUriAction.launchExternal;
}

Uri? intentNativeUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'intent') return null;
  final RegExpMatch? match = RegExp(r'(?:^|;)scheme=([^;]+)').firstMatch(uri.fragment);
  if (match == null) return uri;
  final String scheme = match.group(1)!.trim();
  if (scheme.isEmpty) return null;
  return Uri(
    scheme: scheme,
    host: uri.host,
    path: uri.path,
    query: uri.hasQuery ? uri.query : null,
  );
}

Uri? intentFallbackUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'intent') return null;
  final RegExpMatch? match = RegExp(
    r'S\.browser_fallback_url=([^;]+)',
  ).firstMatch(uri.toString());
  if (match == null) return null;
  final Uri? fallback = Uri.tryParse(Uri.decodeComponent(match.group(1)!));
  if (fallback == null ||
      !<String>{'http', 'https'}.contains(fallback.scheme.toLowerCase())) {
    return null;
  }
  return fallback;
}

List<Uri> externalUriCandidates(Uri uri) {
  if (uri.scheme.toLowerCase() != 'intent') return <Uri>[uri];
  return <Uri>[
    ?intentNativeUri(uri),
    ?intentFallbackUri(uri),
  ];
}

Future<bool> launchExternalUri(
  Uri uri, {
  WebViewController? controller,
}) async {
  for (final Uri candidate in externalUriCandidates(uri)) {
    try {
      if (controller != null && <String>{'http', 'https'}.contains(candidate.scheme.toLowerCase())) {
        await controller.loadRequest(candidate);
        return true;
      }
      final bool opened = await launchUrl(
        candidate,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return true;
    } catch (_) {}
  }
  return false;
}

bool shouldInjectCompatibilityStyle(String currentUrl, String storeHost) {
  final Uri? current = Uri.tryParse(currentUrl);
  final String store = storeHost.trim().toLowerCase();
  if (current == null || store.isEmpty) return false;
  final String host = current.host.toLowerCase();
  return host == store || host.endsWith('.$store');
}

String webViewCompatibilityScript({
  required bool mapLocalhost,
  String currentUrl = '',
  String storeHost = '',
}) {
  final bool injectTheme = shouldInjectCompatibilityStyle(currentUrl, storeHost);
  final String themeStyle = injectTheme
      ? '''
  var meta = document.querySelector('meta[name="viewport"]');
  if (!meta) {
    meta = document.createElement('meta');
    meta.name = 'viewport';
    head.appendChild(meta);
  }
  meta.setAttribute('content', 'width=device-width, initial-scale=1.0');
  if (!document.getElementById('wptf-compatibility-style')) {
    var style = document.createElement('style');
    style.id = 'wptf-compatibility-style';
    style.textContent =
      'html, body { max-width: 100%; overflow-x: clip; } ' +
      'img, video, iframe { max-width: 100%; }';
    head.appendChild(style);
  }
'''
      : '';
  final String localMapper = mapLocalhost && injectTheme
      ? r'''
  var fix = function (value) {
    return String(value).replace('://localhost/', '://10.0.2.2/').replace('://127.0.0.1/', '://10.0.2.2/');
  };
  var images = document.querySelectorAll('img[src], img[data-src], img[srcset]');
  for (var i = 0; i < images.length; i++) {
    var img = images[i];
    if (img.src && img.src.indexOf('://localhost/') !== -1) { img.src = fix(img.src); }
    if (img.dataset && img.dataset.src && img.dataset.src.indexOf('://localhost/') !== -1) { img.dataset.src = fix(img.dataset.src); }
    if (img.srcset && img.srcset.indexOf('://localhost/') !== -1) { img.srcset = fix(img.srcset); }
  }
  var links = document.querySelectorAll('a[href^="http://localhost/"], a[href^="http://127.0.0.1/"]');
  for (var j = 0; j < links.length; j++) { links[j].href = fix(links[j].href); }
'''
      : '';
  return '''
(function() {
  try {
    if (window.__wptfCompatibilityInstalled) { return; }
    window.__wptfCompatibilityInstalled = true;
    var head = document.head || document.documentElement;
    if (!head) { return; }
    $themeStyle
    document.addEventListener('click', function (event) {
      var anchor = event.target && event.target.closest ? event.target.closest('a[target="_blank"]') : null;
      if (anchor && anchor.href) {
        event.preventDefault();
        window.location.href = anchor.href;
      }
    }, true);
    document.addEventListener('submit', function (event) {
      var form = event.target;
      if (form && form.target === '_blank') { form.target = '_self'; }
    }, true);
    window.open = function (url) {
      if (url) { window.location.href = url; }
      return {
        closed: false,
        location: window.location,
        focus: function () {},
        close: function () {}
      };
    };
    $localMapper
  } catch (e) {}
})();
''';
}

Future<void> handlePushedWebViewBack({
  required bool canGoBack,
  required Future<void> Function() goBack,
  required VoidCallback popRoute,
}) async {
  if (canGoBack) {
    await goBack();
  } else {
    popRoute();
  }
}

Future<void> configureAndroidWebView(
  WebViewController controller,
  BuildContext context,
) async {
  if (controller.platform is! AndroidWebViewController) return;
  final AndroidWebViewController android =
      controller.platform as AndroidWebViewController;
  await android.setMixedContentMode(MixedContentMode.alwaysAllow);
  await android.setUseWideViewPort(true);
  await android.enableZoom(true);
  await android.setOverScrollMode(WebViewOverScrollMode.ifContentScrolls);
  await android.setAllowFileAccess(true);
  await android.setAllowContentAccess(true);
  await android.setUserAgent(
    'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
  );
  final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
    const PlatformWebViewCookieManagerCreationParams(),
  );
  await cookies.setAcceptThirdPartyCookies(android, true);

  await android.setOnShowFileSelector((FileSelectorParams params) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        withData: false,
      );
      return result?.files
              .map((PlatformFile file) => file.path)
              .whereType<String>()
              .toList(growable: false) ??
          <String>[];
    } catch (_) {
      return <String>[];
    }
  });

  await android.setOnJavaScriptAlertDialog((
    JavaScriptAlertDialogRequest request,
  ) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(request.message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  });

  await android.setOnJavaScriptConfirmDialog((
    JavaScriptConfirmDialogRequest request,
  ) async {
    if (!context.mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            content: Text(request.message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('تأیید'),
              ),
            ],
          ),
        ) ??
        false;
  });

  await android.setOnJavaScriptTextInputDialog((
    JavaScriptTextInputDialogRequest request,
  ) async {
    if (!context.mounted) return request.defaultText ?? '';
    final TextEditingController input = TextEditingController(
      text: request.defaultText,
    );
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(request.message),
            TextField(controller: input, autofocus: true),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(input.text),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    input.dispose();
    return result ?? request.defaultText ?? '';
  });
}
