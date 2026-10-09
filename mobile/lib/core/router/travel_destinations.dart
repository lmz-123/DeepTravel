/// One destination for location listening, including historical deep links.
String companionLocation(String? routeSlug,
        {bool requestSelection = false, String? fragmentId}) =>
    Uri(
      path: '/',
      queryParameters: {
        'tab': 'companion',
        if (fragmentId != null) 'fragment': fragmentId,
        if (routeSlug != null && routeSlug.isNotEmpty) 'route': routeSlug,
        if (requestSelection)
          'selection': DateTime.now().microsecondsSinceEpoch.toString(),
      },
    ).toString();
