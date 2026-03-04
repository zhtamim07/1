import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import '../services/game_pass_api.dart';

class WallpaperScreen extends StatefulWidget {
  final String titleSlug;
  final String productId;

  const WallpaperScreen({
    super.key,
    required this.titleSlug,
    required this.productId,
  });

  @override
  State<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen> {
  bool _isLoading = true;
  Map<String, String> _wallpapers = {};

  @override
  void initState() {
    super.initState();
    _fetchWallpapers();
  }

  Future<void> _fetchWallpapers() async {
    final titleInfo = await GamePassApi.getTitleInfo(widget.productId);
    
    if (titleInfo != null && mounted) {
      final banner = GamePassApi.extractImageUrl(titleInfo, 'Hero');
      final poster = GamePassApi.extractImageUrl(titleInfo, 'Poster');
      final bannerTitled = GamePassApi.extractImageUrl(titleInfo, 'TitledHero');

      setState(() {
        if (banner != null) _wallpapers['Banner'] = '$banner?format=png';
        if (poster != null) _wallpapers['Poster'] = '$poster?format=png';
        if (bannerTitled != null) _wallpapers['Titled Banner'] = '$bannerTitled?format=png';
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load wallpapers')));
    }
  }

  Future<void> _downloadWallpaper(String url, String name) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading $name...')));
    try {
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final result = await ImageGallerySaver.saveImage(
            Uint8List.fromList(response.bodyBytes),
            quality: 100,
            name: "${widget.titleSlug}_$name");
            
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['isSuccess'] ? 'Saved to Photos' : 'Failed to save')));
        }
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download Error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Wallpapers: ${widget.titleSlug}'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _wallpapers.isEmpty
          ? const Center(child: Text('No wallpapers found', style: TextStyle(color: Colors.white)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _wallpapers.entries.map((entry) {
                return Card(
                  color: const Color(0xFF1A1A1A),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                       Padding(
                         padding: const EdgeInsets.all(8.0),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text(entry.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                             IconButton(
                               icon: const Icon(Icons.download, color: Color(0xFF107C10)),
                               onPressed: () => _downloadWallpaper(entry.value, entry.key),
                             )
                           ],
                         ),
                       ),
                       Image.network(entry.value, fit: BoxFit.contain),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}
