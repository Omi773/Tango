import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:mornye/models/track.dart';
import 'package:mornye/services/history_database.dart';
import 'package:mornye/services/platform_bridge.dart';

/// Discord fetches images itself. Local artwork must never be sent as an asset
/// key, and private/signed URLs must not be published as listening activity.
String? discordPublicArtwork(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.toString().length > 300) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (!host.contains('.') ||
      host.endsWith('.local') ||
      host.endsWith('.localhost') ||
      host.endsWith('.internal') ||
      InternetAddress.tryParse(host) != null) {
    return null;
  }
  // Image CDN transforms are public, unlike authentication/signature params.
  const transforms = {
    'w',
    'h',
    'width',
    'height',
    'size',
    'quality',
    'q',
    'format',
    'fm',
    'fit',
    'crop',
    'auto',
  };
  if (uri.queryParametersAll.entries.any(
    (entry) =>
        !transforms.contains(entry.key.toLowerCase()) ||
        entry.value.any(
          (value) => !RegExp(r'^[a-zA-Z0-9,._-]{1,40}$').hasMatch(value),
        ),
  )) {
    return null;
  }
  return uri.toString();
}

String _normalized(String? text) =>
    (text ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

final _artistSplit = RegExp(r'\s*(?:,|&|;|/|\bfeat\.?|\bft\.?)\s*');

/// "Travis Scott, SoFaygo" and "Travis Scott & SoFaygo" are the same artists.
Set<String> _artistSet(String? text) {
  final normalized = _normalized(text);
  final parts = normalized
      .split(_artistSplit)
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet();
  return parts.isEmpty ? {normalized} : parts;
}

bool _sameArtists(String? a, String? b) {
  final left = _artistSet(a);
  final right = _artistSet(b);
  return left.length == right.length && left.containsAll(right);
}

/// Strictly retain version/album qualifiers: a remix, single or reissue must
/// not borrow another release's cover merely because it ranked first in
/// search. Among exact matches the closest duration wins.
String? discordMatchedArtwork(MediaItem item, Iterable<Track> candidates) {
  final title = _normalized(item.title);
  final album = _normalized(item.album);
  String? best;
  var bestDelta = 1 << 30;
  for (final track in candidates) {
    if (_normalized(track.name) != title ||
        !_sameArtists(track.artistName, item.artist) ||
        (album.isNotEmpty && _normalized(track.albumName) != album)) {
      continue;
    }
    var delta = 0;
    if (item.duration != null && track.duration > 0) {
      delta = (item.duration!.inSeconds - track.duration).abs();
      if (delta > 3) continue;
    }
    final cover = discordPublicArtwork(track.coverUrl);
    if (cover == null || delta >= bestDelta) continue;
    best = cover;
    bestDelta = delta;
  }
  return best;
}

class DiscordArtworkResolver {
  DiscordArtworkResolver({
    Future<String?> Function(MediaItem)? historyCover,
    Future<List<Track>> Function(String)? search,
  }) : _historyCover = historyCover ?? _fromHistory,
       _search = search ?? _searchCatalog;

  final Future<String?> Function(MediaItem) _historyCover;
  final Future<List<Track>> Function(String) _search;
  final _cache = <String, ({String? url, DateTime expires})>{};
  final _pending = <String, Future<String?>>{};

  Future<String?> resolve(MediaItem item) async {
    final direct = discordPublicArtwork(item.artUri?.toString());
    if (direct != null) return direct;
    final key = [
      item.id,
      item.title,
      item.artist,
      item.album,
      item.artUri,
      item.duration,
    ].join('\u0000');
    final cached = _cache[key];
    if (cached != null && cached.expires.isAfter(DateTime.now())) {
      return cached.url;
    }
    if (_pending[key] case final pending?) return pending;
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    final request = _lookup(
      item,
      deadline,
    ).timeout(const Duration(seconds: 8), onTimeout: () => null);
    _pending[key] = request;
    try {
      final url = await request;
      _cache.remove(key);
      while (_cache.length >= 64) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = (
        url: url,
        expires: DateTime.now().add(Duration(minutes: url == null ? 5 : 60)),
      );
      return url;
    } finally {
      _pending.remove(key);
    }
  }

  Future<String?> _lookup(MediaItem item, DateTime deadline) async {
    final title = item.title.trim();
    final artist = (item.artist ?? '').trim();
    final album = (item.album ?? '').trim();
    if (title.isNotEmpty && artist.isNotEmpty) {
      final queries = [
        if (album.isNotEmpty) '$title $artist $album',
        '$title $artist',
      ];
      for (final query in queries) {
        if (!DateTime.now().isBefore(deadline)) break;
        try {
          final matched = discordMatchedArtwork(item, await _search(query));
          if (matched != null) return matched;
        } catch (_) {
          /* Artwork is optional; try the next query. */
        }
      }
    }
    // A saved cover cannot be checked against this release. When the album is
    // known and no catalog entry matched, show no artwork rather than a
    // different edition's cover.
    if (album.isNotEmpty) return null;
    try {
      return discordPublicArtwork(await _historyCover(item));
    } catch (_) {
      return null; // Library access must not block presence.
    }
  }

  static Future<String?> _fromHistory(MediaItem item) async {
    final source = item.extras?['source'];
    final row = source is String && source.isNotEmpty
        ? await HistoryDatabase.instance.findByFilePath(source)
        : await HistoryDatabase.instance.getById(item.id);
    return row?['coverUrl'] as String?;
  }

  static Future<List<Track>> _searchCatalog(String query) async => [
    for (final row in await PlatformBridge.searchTracksWithMetadataProviders(
      query,
      limit: 8,
      includeExtensions: true,
    ))
      Track.fromBackendMap(row),
  ];
}