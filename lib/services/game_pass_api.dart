import 'dart:convert';
import 'package:http/http.dart' as http;

class GamePassApi {
  static const String baseUrl = 'https://displaycatalog.mp.microsoft.com/v7.0/products';

  static Future<Map<String, dynamic>?> getTitleInfo(String productId, {String region = 'US', String language = 'en-US'}) async {
    try {
      final uri = Uri.parse('\$baseUrl?bigIds=\$productId&market=\$region&languages=\$language&MS-CV=DUMMY.1');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['Products'] != null && (data['Products'] as List).isNotEmpty) {
          return data['Products'][0];
        }
      }
      return null;
    } catch (e) {
      print('Failed to get title info: \$e');
      return null;
    }
  }

  static String? extractImageUrl(Map<String, dynamic> product, String imagePurpose) {
    try {
      final localizedProperties = product['LocalizedProperties'] as List?;
      if (localizedProperties != null && localizedProperties.isNotEmpty) {
        final images = localizedProperties[0]['Images'] as List?;
        if (images != null) {
          for (var img in images) {
            if (img['ImagePurpose'] == imagePurpose) {
              return img['Uri']?.toString().replaceFirst(RegExp(r'^//'), 'https://');
            }
          }
        }
      }
    } catch (e) {
      print('Failed to extract image: \$e');
    }
    return null;
  }
}
