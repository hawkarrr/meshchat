import 'dart:convert';
import 'dart:typed_data';

import '../core/bytes.dart';
import 'protocol_constants.dart';

/// Thrown when decrypted (or public) message content is malformed.
class EnvelopeFormatException extends FormatException {
  const EnvelopeFormatException(super.message);
}

/// What a message envelope contains.
enum ContentKind {
  text(1),
  image(2),
  voice(3),
  groupInvite(10),
  groupUpdate(11),
  groupRemoved(12),
  groupLeave(13),

  /// A short video clip (private chats and groups only).
  video(4),

  /// Replaces the text of an earlier message by the same author.
  edit(20),

  /// Asks everyone in the conversation to remove earlier messages.
  delete(21);

  const ContentKind(this.code);

  final int code;

  static ContentKind? fromCode(int code) {
    for (final k in ContentKind.values) {
      if (k.code == code) return k;
    }
    return null;
  }
}

/// Images, voice messages and videos.
enum MediaKind {
  image,
  voice,
  video;

  ContentKind get contentKind => switch (this) {
        MediaKind.image => ContentKind.image,
        MediaKind.voice => ContentKind.voice,
        MediaKind.video => ContentKind.video,
      };

  /// The largest object of this kind, before encryption.
  int get maxBytes => this == MediaKind.video ? Protocol.maxVideoBytes : Protocol.maxMediaBytes;
}

/// Media container, so a receiver knows how to show or play the bytes.
abstract final class MediaMime {
  static const int jpeg = 1;

  /// AAC-LC audio in an MP4 (.m4a) container: what both Android and iOS record
  /// and play without extra codecs.
  static const int aacM4a = 2;

  /// MPEG-4 video (H.264 with AAC), what both Android and iOS record and play.
  static const int mp4 = 3;

  static bool valid(MediaKind kind, int code) => switch (kind) {
        MediaKind.image => code == jpeg,
        MediaKind.voice => code == aacM4a,
        MediaKind.video => code == mp4,
      };

  static String extension(int code) => switch (code) {
        jpeg => 'jpg',
        aacM4a => 'm4a',
        mp4 => 'mp4',
        _ => 'bin',
      };
}

/// The plaintext of one message. Direct and group messages are sealed before
/// they leave the phone; public-room messages are sent as they are (but
/// signed). Group-control envelopes are only ever sent sealed, one-to-one.
sealed class Envelope {
  const Envelope();

  ContentKind get kind;
}

class TextEnvelope extends Envelope {
  const TextEnvelope(this.text, {this.nickname, this.replyTo, this.forwardedFrom});

  final String text;

  /// The author's display name. Carried in group and room messages, where the
  /// reader may never have met the author; left out of direct messages.
  final String? nickname;

  /// Id of the message this one answers. Only the id travels: the reader shows
  /// the quoted text from their own copy, if they have it and it still exists.
  final Uint8List? replyTo;

  /// The name of the person who wrote this message originally, when it was
  /// forwarded. A name for display, not an identity: it proves nothing.
  final String? forwardedFrom;

  @override
  ContentKind get kind => ContentKind.text;
}

/// Describes an image or a voice message. The bytes themselves follow as
/// chunk packets; this envelope tells the receiver how many to expect and how
/// to check them.
class MediaEnvelope extends Envelope {
  const MediaEnvelope({
    required this.mediaKind,
    required this.mediaId,
    required this.mimeCode,
    required this.byteLength,
    required this.chunkCount,
    required this.sha256,
    this.key,
    this.width = 0,
    this.height = 0,
    this.durationMs = 0,
    this.waveform = const <int>[],
    this.caption = '',
    this.nickname,
    this.replyTo,
    this.forwardedFrom,
  });

  final MediaKind mediaKind;

  /// Random id tying the chunks to this manifest.
  final Uint8List mediaId;
  final int mimeCode;

  /// Size of the media object before encryption.
  final int byteLength;
  final int chunkCount;

  /// SHA-256 of the whole media object. Receivers check it after reassembly,
  /// so a missing, reordered or substituted chunk is always noticed.
  final Uint8List sha256;

  /// Key the chunks are sealed with. Present in direct messages only (the
  /// manifest is itself sealed to the recipient); group media derives its key
  /// from the group key, public media is not sealed.
  final Uint8List? key;

  final int width;
  final int height;
  final int durationMs;

  /// Amplitude samples (0..255) for drawing a voice waveform.
  final List<int> waveform;
  final String caption;
  final String? nickname;

  /// See [TextEnvelope.replyTo] and [TextEnvelope.forwardedFrom].
  final Uint8List? replyTo;
  final String? forwardedFrom;

  @override
  ContentKind get kind => mediaKind.contentKind;

  String get mediaIdHex => bytesToHex(mediaId);
}

/// "Replace the text of my earlier message." Only the author's edit counts,
/// and only a newer [version] than what the reader already has: a late or
/// repeated event can never put an old text back.
class EditEnvelope extends Envelope {
  const EditEnvelope({required this.targetId, required this.version, required this.text});

  /// The message being edited (16 bytes).
  final Uint8List targetId;

  /// The author's clock when the edit was made, in milliseconds. Larger wins.
  final int version;
  final String text;

  @override
  ContentKind get kind => ContentKind.edit;

  String get targetHex => bytesToHex(targetId);
}

/// "Remove these messages." Valid from their author (and, in a group, from
/// its admin). A phone that has not got a message yet remembers the request,
/// so the message is dropped if it arrives later.
class DeleteEnvelope extends Envelope {
  const DeleteEnvelope(this.targets);

  /// 1 to [Protocol.maxDeleteBatch] message ids, 16 bytes each.
  final List<Uint8List> targets;

  @override
  ContentKind get kind => ContentKind.delete;

  List<String> get targetsHex => [for (final t in targets) bytesToHex(t)];
}

/// One member of a group, as shared in an invitation.
class GroupMemberInfo {
  const GroupMemberInfo({required this.key, required this.nickname});

  /// The member's Ed25519 identity key.
  final Uint8List key;
  final String nickname;

  String get id => bytesToHex(key);
}

/// Everything a phone needs to take part in a group: sent sealed to each new
/// member (an invitation) and to existing members when the admin changes the
/// group (an update).
class GroupSnapshot extends Envelope {
  const GroupSnapshot({
    required this.isUpdate,
    required this.groupId,
    required this.epoch,
    required this.groupKey,
    required this.name,
    required this.adminKey,
    required this.members,
  });

  /// False for the first invitation, true for later changes.
  final bool isUpdate;
  final Uint8List groupId;

  /// Counts key rotations. Messages say which epoch's key sealed them.
  final int epoch;
  final Uint8List groupKey;
  final String name;
  final Uint8List adminKey;
  final List<GroupMemberInfo> members;

  @override
  ContentKind get kind => isUpdate ? ContentKind.groupUpdate : ContentKind.groupInvite;

  String get groupIdHex => bytesToHex(groupId);
  String get adminId => bytesToHex(adminKey);
}

/// "You are no longer in this group" (sent by the admin).
class GroupRemovedEnvelope extends Envelope {
  const GroupRemovedEnvelope(this.groupId);

  final Uint8List groupId;

  @override
  ContentKind get kind => ContentKind.groupRemoved;
}

/// "I left this group" (sent to the admin, who then rotates the key).
class GroupLeaveEnvelope extends Envelope {
  const GroupLeaveEnvelope(this.groupId);

  final Uint8List groupId;

  @override
  ContentKind get kind => ContentKind.groupLeave;
}

/// Binary codec for [Envelope]s.
///
/// Layout (big-endian):
///
/// ```
/// text:        u8 1   [u8 nickLen nick]  links  u16 len  text
/// image/voice/video: u8 2|3|4 [u8 nickLen nick]  links  mediaId[16] u8 mime u32 byteLength
///              u16 chunkCount sha256[32] u8 hasKey [key[32]]
///              image: u16 width u16 height
///              voice: u32 durationMs u8 waveformLen waveform
///              video: u16 width u16 height u32 durationMs
///              u16 captionLen caption
/// group:       u8 10|11 groupId[32] u32 epoch key[32] u8 nameLen name
///              adminKey[32] u8 memberCount { memberKey[32] u8 nickLen nick }
/// removed:     u8 12 groupId[32]
/// leave:       u8 13 groupId[32]
/// edit:        u8 20 targetId[16] u64 version u16 len text
/// delete:      u8 21 u8 count targetId[16] x count
///
/// links:       u8 flags (1 = reply, 2 = forwarded) [replyTo[16]] [u8 len name]
/// ```
///
/// Everything read from the network is bounds- and range-checked, and trailing
/// bytes other than zero padding are rejected.
abstract final class EnvelopeCodec {
  static Uint8List encode(Envelope e, {required bool withNickname}) {
    final w = ByteWriter()..u8(e.kind.code);
    switch (e) {
      case TextEnvelope():
        _writeNickname(w, e.nickname, withNickname);
        final bytes = utf8.encode(e.text);
        if (e.text.trim().isEmpty) {
          throw ArgumentError.value(e.text, 'text', 'is empty');
        }
        if (bytes.length > Protocol.maxTextBytes) {
          throw ArgumentError.value(e.text, 'text', 'exceeds ${Protocol.maxTextBytes} bytes');
        }
        _writeLinks(w, e.replyTo, e.forwardedFrom);
        w
          ..u16(bytes.length)
          ..bytes(bytes);
      case MediaEnvelope():
        _validateMedia(e);
        _writeNickname(w, e.nickname, withNickname);
        _writeLinks(w, e.replyTo, e.forwardedFrom);
        w
          ..bytes(e.mediaId)
          ..u8(e.mimeCode)
          ..u32(e.byteLength)
          ..u16(e.chunkCount)
          ..bytes(e.sha256);
        final key = e.key;
        if (key == null) {
          w.u8(0);
        } else {
          w
            ..u8(1)
            ..bytes(key);
        }
        switch (e.mediaKind) {
          case MediaKind.image:
            w
              ..u16(e.width)
              ..u16(e.height);
          case MediaKind.voice:
            w
              ..u32(e.durationMs)
              ..u8(e.waveform.length)
              ..bytes(e.waveform);
          case MediaKind.video:
            w
              ..u16(e.width)
              ..u16(e.height)
              ..u32(e.durationMs);
        }
        final caption = utf8.encode(e.caption);
        w
          ..u16(caption.length)
          ..bytes(caption);
      case EditEnvelope():
        _requireLength(e.targetId, Protocol.messageIdLength, 'targetId');
        final bytes = utf8.encode(e.text);
        if (e.text.trim().isEmpty) {
          throw ArgumentError.value(e.text, 'text', 'is empty');
        }
        if (bytes.length > Protocol.maxTextBytes) {
          throw ArgumentError.value(e.text, 'text', 'exceeds ${Protocol.maxTextBytes} bytes');
        }
        if (e.version <= 0) throw ArgumentError.value(e.version, 'version', 'must be positive');
        w
          ..bytes(e.targetId)
          ..u64(e.version)
          ..u16(bytes.length)
          ..bytes(bytes);
      case DeleteEnvelope():
        if (e.targets.isEmpty || e.targets.length > Protocol.maxDeleteBatch) {
          throw ArgumentError.value(e.targets.length, 'targets', 'must be 1 to ${Protocol.maxDeleteBatch}');
        }
        w.u8(e.targets.length);
        for (final t in e.targets) {
          _requireLength(t, Protocol.messageIdLength, 'target');
          w.bytes(t);
        }
      case GroupSnapshot():
        _validateGroup(e);
        w
          ..bytes(e.groupId)
          ..u32(e.epoch)
          ..bytes(e.groupKey);
        final name = utf8.encode(e.name);
        w
          ..u8(name.length)
          ..bytes(name)
          ..bytes(e.adminKey)
          ..u8(e.members.length);
        for (final m in e.members) {
          final nick = utf8.encode(m.nickname);
          w
            ..bytes(m.key)
            ..u8(nick.length)
            ..bytes(nick);
        }
      case GroupRemovedEnvelope():
        _requireLength(e.groupId, Protocol.keyLength, 'groupId');
        w.bytes(e.groupId);
      case GroupLeaveEnvelope():
        _requireLength(e.groupId, Protocol.keyLength, 'groupId');
        w.bytes(e.groupId);
    }
    return w.toBytes();
  }

  static Envelope decode(Uint8List plain, {required bool withNickname}) {
    try {
      final r = ByteReader(plain);
      final kind = ContentKind.fromCode(r.u8());
      if (kind == null) throw const EnvelopeFormatException('Unknown content kind');
      final Envelope result;
      switch (kind) {
        case ContentKind.text:
          final nick = _readNickname(r, withNickname);
          final links = _readLinks(r);
          final len = r.u16();
          if (len == 0 || len > Protocol.maxTextBytes) {
            throw const EnvelopeFormatException('Bad text length');
          }
          final text = utf8.decode(r.bytes(len));
          if (text.trim().isEmpty) throw const EnvelopeFormatException('Empty text');
          result = TextEnvelope(text,
              nickname: nick, replyTo: links.replyTo, forwardedFrom: links.forwardedFrom);
        case ContentKind.image:
        case ContentKind.voice:
        case ContentKind.video:
          final mediaKind = switch (kind) {
            ContentKind.image => MediaKind.image,
            ContentKind.voice => MediaKind.voice,
            _ => MediaKind.video,
          };
          final nick = _readNickname(r, withNickname);
          final links = _readLinks(r);
          final mediaId = r.bytes(Protocol.messageIdLength);
          final mime = r.u8();
          final byteLength = r.u32();
          final chunkCount = r.u16();
          final sha = r.bytes(32);
          final hasKey = r.u8();
          if (hasKey > 1) throw const EnvelopeFormatException('Bad key flag');
          final key = hasKey == 1 ? r.bytes(Protocol.keyLength) : null;
          var width = 0, height = 0, durationMs = 0;
          var waveform = Uint8List(0);
          switch (mediaKind) {
            case MediaKind.image:
              width = r.u16();
              height = r.u16();
            case MediaKind.voice:
              durationMs = r.u32();
              final n = r.u8();
              if (n > Protocol.maxWaveformSamples) {
                throw const EnvelopeFormatException('Waveform too long');
              }
              waveform = r.bytes(n);
            case MediaKind.video:
              width = r.u16();
              height = r.u16();
              durationMs = r.u32();
          }
          final captionLength = r.u16();
          if (captionLength > Protocol.maxCaptionBytes) {
            throw const EnvelopeFormatException('Caption too long');
          }
          final caption = utf8.decode(r.bytes(captionLength));
          final media = MediaEnvelope(
            mediaKind: mediaKind,
            mediaId: mediaId,
            mimeCode: mime,
            byteLength: byteLength,
            chunkCount: chunkCount,
            sha256: sha,
            key: key,
            width: width,
            height: height,
            durationMs: durationMs,
            waveform: waveform,
            caption: caption,
            nickname: nick,
            replyTo: links.replyTo,
            forwardedFrom: links.forwardedFrom,
          );
          _validateMedia(media);
          result = media;
        case ContentKind.edit:
          final target = r.bytes(Protocol.messageIdLength);
          final version = r.u64();
          if (version <= 0) throw const EnvelopeFormatException('Bad edit version');
          final len = r.u16();
          if (len == 0 || len > Protocol.maxTextBytes) {
            throw const EnvelopeFormatException('Bad text length');
          }
          final text = utf8.decode(r.bytes(len));
          if (text.trim().isEmpty) throw const EnvelopeFormatException('Empty text');
          result = EditEnvelope(targetId: target, version: version, text: text);
        case ContentKind.delete:
          final count = r.u8();
          if (count == 0 || count > Protocol.maxDeleteBatch) {
            throw const EnvelopeFormatException('Bad delete count');
          }
          result = DeleteEnvelope([for (var i = 0; i < count; i++) r.bytes(Protocol.messageIdLength)]);
        case ContentKind.groupInvite:
        case ContentKind.groupUpdate:
          final groupId = r.bytes(Protocol.keyLength);
          final epoch = r.u32();
          final key = r.bytes(Protocol.keyLength);
          final nameLength = r.u8();
          final name = utf8.decode(r.bytes(nameLength));
          final admin = r.bytes(Protocol.keyLength);
          final count = r.u8();
          if (count == 0 || count > Protocol.maxGroupMembers) {
            throw const EnvelopeFormatException('Bad member count');
          }
          final members = <GroupMemberInfo>[];
          for (var i = 0; i < count; i++) {
            final memberKey = r.bytes(Protocol.keyLength);
            final nickLength = r.u8();
            if (nickLength > Protocol.maxNicknameBytes) {
              throw const EnvelopeFormatException('Nickname too long');
            }
            members.add(GroupMemberInfo(key: memberKey, nickname: utf8.decode(r.bytes(nickLength))));
          }
          final snapshot = GroupSnapshot(
            isUpdate: kind == ContentKind.groupUpdate,
            groupId: groupId,
            epoch: epoch,
            groupKey: key,
            name: name,
            adminKey: admin,
            members: members,
          );
          _validateGroup(snapshot);
          result = snapshot;
        case ContentKind.groupRemoved:
          result = GroupRemovedEnvelope(r.bytes(Protocol.keyLength));
        case ContentKind.groupLeave:
          result = GroupLeaveEnvelope(r.bytes(Protocol.keyLength));
      }
      if (!isAllZero(r.rest())) {
        throw const EnvelopeFormatException('Unexpected trailing data');
      }
      return result;
    } on EnvelopeFormatException {
      rethrow;
    } on FormatException catch (e) {
      throw EnvelopeFormatException(e.message);
    }
  }

  // ---------------------------------------------------------------------------

  static void _writeNickname(ByteWriter w, String? nickname, bool withNickname) {
    if (!withNickname) return;
    final nick = utf8.encode(nickname ?? '');
    if (nick.length > Protocol.maxNicknameBytes) {
      throw ArgumentError.value(nickname, 'nickname', 'too long');
    }
    w
      ..u8(nick.length)
      ..bytes(nick);
  }

  static String? _readNickname(ByteReader r, bool withNickname) {
    if (!withNickname) return null;
    final n = r.u8();
    if (n > Protocol.maxNicknameBytes) {
      throw const EnvelopeFormatException('Nickname too long');
    }
    return utf8.decode(r.bytes(n));
  }

  static void _writeLinks(ByteWriter w, Uint8List? replyTo, String? forwardedFrom) {
    final fwd = forwardedFrom == null ? null : utf8.encode(forwardedFrom);
    if (replyTo != null && replyTo.length != Protocol.messageIdLength) {
      throw ArgumentError.value(replyTo.length, 'replyTo', 'must be ${Protocol.messageIdLength} bytes');
    }
    if (fwd != null && (fwd.isEmpty || fwd.length > Protocol.maxNicknameBytes)) {
      throw ArgumentError.value(forwardedFrom, 'forwardedFrom', 'is empty or too long');
    }
    w.u8((replyTo == null ? 0 : 1) | (fwd == null ? 0 : 2));
    if (replyTo != null) w.bytes(replyTo);
    if (fwd != null) {
      w
        ..u8(fwd.length)
        ..bytes(fwd);
    }
  }

  static ({Uint8List? replyTo, String? forwardedFrom}) _readLinks(ByteReader r) {
    final flags = r.u8();
    if (flags & ~3 != 0) throw const EnvelopeFormatException('Bad link flags');
    final reply = flags & 1 != 0 ? r.bytes(Protocol.messageIdLength) : null;
    String? forwarded;
    if (flags & 2 != 0) {
      final n = r.u8();
      if (n == 0 || n > Protocol.maxNicknameBytes) {
        throw const EnvelopeFormatException('Bad forwarded-from name');
      }
      forwarded = utf8.decode(r.bytes(n));
    }
    return (replyTo: reply, forwardedFrom: forwarded);
  }

  static void _requireLength(Uint8List v, int length, String what) {
    if (v.length != length) throw ArgumentError.value(v.length, what, 'must be $length bytes');
  }

  /// The number of chunks a media object of [byteLength] bytes is cut into.
  static int chunkCountFor(int byteLength) =>
      (byteLength + Protocol.mediaChunkBytes - 1) ~/ Protocol.mediaChunkBytes;

  static void _validateMedia(MediaEnvelope m) {
    if (m.mediaId.length != Protocol.messageIdLength ||
        m.sha256.length != 32 ||
        (m.key != null && m.key!.length != Protocol.keyLength)) {
      throw const EnvelopeFormatException('Bad media field length');
    }
    if (!MediaMime.valid(m.mediaKind, m.mimeCode)) {
      throw const EnvelopeFormatException('Unsupported media type');
    }
    if (m.byteLength <= 0 || m.byteLength > m.mediaKind.maxBytes) {
      throw const EnvelopeFormatException('Media size out of range');
    }
    if (m.chunkCount != chunkCountFor(m.byteLength) || m.chunkCount > Protocol.maxMediaChunks) {
      throw const EnvelopeFormatException('Chunk count does not match the size');
    }
    if (m.waveform.length > Protocol.maxWaveformSamples) {
      throw const EnvelopeFormatException('Waveform too long');
    }
    if (m.mediaKind != MediaKind.voice && (m.width > 8192 || m.height > 8192)) {
      throw const EnvelopeFormatException('Picture dimensions out of range');
    }
    if (m.mediaKind == MediaKind.video && m.durationMs > const Duration(hours: 1).inMilliseconds) {
      throw const EnvelopeFormatException('Video duration out of range');
    }
    if (m.mediaKind == MediaKind.voice &&
        m.durationMs > Protocol.maxVoiceDuration.inMilliseconds + 5000) {
      throw const EnvelopeFormatException('Voice message too long');
    }
    if (utf8.encode(m.caption).length > Protocol.maxCaptionBytes) {
      throw const EnvelopeFormatException('Caption too long');
    }
  }

  static void _validateGroup(GroupSnapshot g) {
    if (g.groupId.length != Protocol.keyLength ||
        g.groupKey.length != Protocol.keyLength ||
        g.adminKey.length != Protocol.keyLength) {
      throw const EnvelopeFormatException('Bad group field length');
    }
    if (isAllZero(g.groupKey) || isAllZero(g.groupId)) {
      throw const EnvelopeFormatException('Degenerate group key');
    }
    final nameBytes = utf8.encode(g.name).length;
    if (g.name.trim().isEmpty || nameBytes > Protocol.maxGroupNameBytes) {
      throw const EnvelopeFormatException('Bad group name');
    }
    if (g.members.isEmpty || g.members.length > Protocol.maxGroupMembers) {
      throw const EnvelopeFormatException('Bad member count');
    }
    final seen = <String>{};
    var adminListed = false;
    for (final m in g.members) {
      if (m.key.length != Protocol.keyLength || isAllZero(m.key)) {
        throw const EnvelopeFormatException('Bad member key');
      }
      if (utf8.encode(m.nickname).length > Protocol.maxNicknameBytes) {
        throw const EnvelopeFormatException('Nickname too long');
      }
      if (!seen.add(m.id)) throw const EnvelopeFormatException('Duplicate member');
      if (constantTimeEquals(m.key, g.adminKey)) adminListed = true;
    }
    if (!adminListed) throw const EnvelopeFormatException('The admin must be a member');
  }
}
