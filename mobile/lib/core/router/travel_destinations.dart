/// One destination for location listening, including historical deep links.
String companionLocation(String? routeSlug, {bool requestSelection = false}) =>
    Uri(
      path: '/',
      queryParameters: {
        'tab': 'companion',
        if (routeSlug != null && routeSlug.isNotEmpty) 'route': routeSlug,
        if (requestSelection)
          'selection': DateTime.now().microsecondsSinceEpoch.toString(),
      },
    ).toString();
