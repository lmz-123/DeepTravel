class PreparationItem {
  const PreparationItem(this.title, this.body, this.url);
  final String title, body, url;
}

class TravelPreparation {
  const TravelPreparation(this.data);
  final Map<String, dynamic> data;
  factory TravelPreparation.fromJson(Object? json) => TravelPreparation(
      json is Map ? Map<String, dynamic>.from(json) : const {});
  String text(String key) =>
      data[key] is String ? (data[key] as String).trim() : '';
  bool get enabled => data['enabled'] == true;
  String get admission => text('admission');
  String get channel => text('channel_name');
  String get purchaseUrl =>
      safePreparationUri(text('purchase_url'))?.toString() ?? '';
  bool get canBook =>
      enabled &&
      ['ticket', 'reservation'].contains(admission) &&
      purchaseUrl.isNotEmpty;
  bool get external => text('launch_mode') == 'external';
  String get action => admission == 'reservation' ? '预约参观' : '前往官方购票';
  List<PreparationItem> get items => [
        PreparationItem('开放时间', text('opening_hours'), text('opening_url')),
        PreparationItem('到达与停车', text('transport'), text('transport_url')),
        PreparationItem('入园须知', text('notices'), text('notices_url')),
        for (final item in (data['extra_items'] is List
            ? data['extra_items'] as List
            : const []))
          if (item is Map && item['title'] is String)
            PreparationItem(
                item['title'] as String,
                item['body'] is String ? item['body'] as String : '',
                item['url'] is String ? item['url'] as String : ''),
      ]
          .where((item) =>
              item.body.isNotEmpty || safePreparationUri(item.url) != null)
          .toList();
}

/// Only editorial public web links. Never launch arbitrary app/file/javascript URIs.
Uri? safePreparationUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.host.isEmpty ||
      !uri.host.contains('.') ||
      uri.port != 443 ||
      uri.host.endsWith('.local') ||
      uri.host.endsWith('.localhost') ||
      uri.host.endsWith('.internal') ||
      uri.host.contains(':') ||
      RegExp(r'^\d+(\.\d+){3}$').hasMatch(uri.host) ||
      RegExp(r'[\s\\]').hasMatch(value)) {
    return null;
  }
  return uri;
}
