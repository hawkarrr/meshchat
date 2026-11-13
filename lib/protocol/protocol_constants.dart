/// Wire-protocol constants. Changing any of these is a protocol change and
/// must be accompanied by a bump of [Protocol.version].
abstract final class Protocol {
  /// Version 2 added group and public-room packets, media chunks, and removed
  /// the old password channels. Version 3 added replies and forwards to text
  /// and media, and the edit and delete control events.
  static const int version = 3;

  // ---- Field sizes -------------------------------------------------------
  static const int messageIdLength = 16;
  static const int keyLength = 32;
  static const int signatureLength = 64;

  /// Bytes before the payload: see the layout documented on `MeshPacket`.
  static const int headerLength = 103;

  // ---- Size limits (enforced on send AND receive) -------------------------
  static const int maxPayloadBytes = 2048;
  static const int maxPacketBytes =
      headerLength + maxPayloadBytes + signatureLength;

  /// Maximum UTF-8 size of one chat message body.
  static const int maxTextBytes = 1000;
  static const int maxNicknameBytes = 32;
  static const int maxGroupNameBytes = 32;
  static const int maxRoomNameBytes = 32;
  static const int maxRoomDescriptionBytes = 96;
  static const int maxCaptionBytes = 200;

  /// Most messages one delete request can name.
  static const int maxDeleteBatch = 16;

  /// How many edits that arrived before the message they change are kept. Edits are
  /// signed, but a member of a group can still send as many as the link allows, each
  /// for a message that does not exist; the oldest go first, so the table cannot
  /// grow without end.
  static const int maxPendingEdits = 500;

  /// The same for the memos of deletions other phones asked for (kept so that a
  /// message that arrives after its deletion request does not appear). Records of
  /// messages deleted here are not counted: they are bounded by what the person did.
  static const int maxRemoteDeletionRecords = 5000;

  /// Largest group (including its admin). Every invitation carries the whole
  /// member list and must fit in one packet.
  static const int maxGroupMembers = 12;

  /// Largest link-level frame (type byte + packet) the reassembler accepts.
  static const int maxFrameBytes = 1 + maxPacketBytes + 64;

  // ---- Media (images and voice messages) -----------------------------------
  //
  // A Bluetooth link moves a few kilobytes per second per hop, so media is
  // deliberately small: an image is shrunk to a few dozen kilobytes and a
  // voice message is a short low-bitrate clip. Each object is cut into signed
  // chunks that travel as ordinary mesh packets.

  /// Hard cap on one image or voice object (before encryption).
  static const int maxMediaBytes = 64 * 1024;

  /// Hard cap on one video (before encryption). A video this size is a few
  /// seconds at low quality; it takes minutes to cross even one Bluetooth link,
  /// so the person can lower their own sending limit, and videos are not sent to
  /// public rooms at all.
  static const int maxVideoBytes = 512 * 1024;

  /// Media bytes carried by one chunk packet.
  static const int mediaChunkBytes = 1536;

  /// ceil(maxVideoBytes / mediaChunkBytes), with headroom.
  static const int maxMediaChunks = 352;

  /// Amplitude samples stored with a voice message so it can show a waveform
  /// without decoding the audio.
  static const int maxWaveformSamples = 48;

  /// Longest voice message the app records.
  static const Duration maxVoiceDuration = Duration(seconds: 30);

  // ---- Hop limits ---------------------------------------------------------
  /// Hard upper bound accepted from the network, whatever the sender claims.
  static const int maxHopLimit = 7;
  static const int directHopLimit = 5;
  static const int groupHopLimit = 5;
  static const int roomHopLimit = 5;
  static const int announceHopLimit = 3;
  static const int roomAnnounceHopLimit = 4;
  static const int ackHopLimit = 5;

  // ---- Lifetimes ----------------------------------------------------------
  static const Duration directMessageTtl = Duration(hours: 12);
  static const Duration groupMessageTtl = Duration(hours: 12);
  static const Duration roomMessageTtl = Duration(hours: 2);
  static const Duration announceTtl = Duration(minutes: 2);
  static const Duration roomAnnounceTtl = Duration(minutes: 5);
  static const Duration ackTtl = Duration(hours: 2);

  /// How long a public room stays listed after its creator last refreshed it.
  static const Duration roomRecordLifetime = Duration(hours: 24);

  /// How long a message in a public room stays on this phone. Counted from
  /// when this phone sent or received it (its own clock), so a wrong clock on
  /// another phone cannot keep it longer or remove it sooner.
  static const Duration publicMessageRetention = Duration(hours: 6);

  /// How long a record of a removed message is kept, so a late copy of it can
  /// be recognised and refused. Longer than any packet lives.
  static const Duration deletionRecordRetention = Duration(hours: 48);

  /// A half-received image or voice message is forgotten after this long.
  static const Duration partialMediaTtl = Duration(hours: 12);

  /// Longest lifetime this node will ever honour for a packet, regardless of
  /// the (untrusted) expiry the sender wrote into it.
  static const Duration maxRetention = Duration(hours: 24);

  /// Tolerance for phones whose clocks disagree when judging expiry.
  static const Duration clockSkewTolerance = Duration(minutes: 5);
}

/// GATT identifiers advertised and hosted by every participating phone.
///
/// A single characteristic carries both directions: centrals WRITE to it and
/// peripherals NOTIFY on it. One characteristic means one CCCD and fewer
/// discovery steps, which keeps the connection sequence short and robust.
abstract final class BleIds {
  static const String serviceUuid = '7f0c1a2e-5d3b-4c8a-9e61-2b4d8f3a6c10';
  static const String dataCharacteristicUuid =
      '7f0c1a2e-5d3b-4c8a-9e61-2b4d8f3a6c11';
}
