// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_music_database.dart';

// ignore_for_file: type=lint
class $LocalSongsTable extends LocalSongs
    with TableInfo<$LocalSongsTable, LocalSongRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discNumberMeta = const VerificationMeta(
    'discNumber',
  );
  @override
  late final GeneratedColumn<int> discNumber = GeneratedColumn<int>(
    'disc_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackNumberMeta = const VerificationMeta(
    'trackNumber',
  );
  @override
  late final GeneratedColumn<int> trackNumber = GeneratedColumn<int>(
    'track_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderPathMeta = const VerificationMeta(
    'folderPath',
  );
  @override
  late final GeneratedColumn<String> folderPath = GeneratedColumn<String>(
    'folder_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bitrateMeta = const VerificationMeta(
    'bitrate',
  );
  @override
  late final GeneratedColumn<int> bitrate = GeneratedColumn<int>(
    'bitrate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sampleRateMeta = const VerificationMeta(
    'sampleRate',
  );
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
    'sample_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasArtworkMeta = const VerificationMeta(
    'hasArtwork',
  );
  @override
  late final GeneratedColumn<int> hasArtwork = GeneratedColumn<int>(
    'has_artwork',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _metadataEditedMeta = const VerificationMeta(
    'metadataEdited',
  );
  @override
  late final GeneratedColumn<int> metadataEdited = GeneratedColumn<int>(
    'metadata_edited',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _scanBatchIdMeta = const VerificationMeta(
    'scanBatchId',
  );
  @override
  late final GeneratedColumn<String> scanBatchId = GeneratedColumn<String>(
    'scan_batch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scanSourceMeta = const VerificationMeta(
    'scanSource',
  );
  @override
  late final GeneratedColumn<String> scanSource = GeneratedColumn<String>(
    'scan_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<int> modifiedAt = GeneratedColumn<int>(
    'modified_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    artist,
    album,
    genre,
    year,
    discNumber,
    trackNumber,
    durationMs,
    filePath,
    folderPath,
    fileSize,
    mimeType,
    bitrate,
    sampleRate,
    hasArtwork,
    metadataEdited,
    status,
    scanBatchId,
    scanSource,
    createdAt,
    updatedAt,
    modifiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSongRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    } else if (isInserting) {
      context.missing(_albumMeta);
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('disc_number')) {
      context.handle(
        _discNumberMeta,
        discNumber.isAcceptableOrUnknown(data['disc_number']!, _discNumberMeta),
      );
    }
    if (data.containsKey('track_number')) {
      context.handle(
        _trackNumberMeta,
        trackNumber.isAcceptableOrUnknown(
          data['track_number']!,
          _trackNumberMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('folder_path')) {
      context.handle(
        _folderPathMeta,
        folderPath.isAcceptableOrUnknown(data['folder_path']!, _folderPathMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('bitrate')) {
      context.handle(
        _bitrateMeta,
        bitrate.isAcceptableOrUnknown(data['bitrate']!, _bitrateMeta),
      );
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
        _sampleRateMeta,
        sampleRate.isAcceptableOrUnknown(data['sample_rate']!, _sampleRateMeta),
      );
    }
    if (data.containsKey('has_artwork')) {
      context.handle(
        _hasArtworkMeta,
        hasArtwork.isAcceptableOrUnknown(data['has_artwork']!, _hasArtworkMeta),
      );
    }
    if (data.containsKey('metadata_edited')) {
      context.handle(
        _metadataEditedMeta,
        metadataEdited.isAcceptableOrUnknown(
          data['metadata_edited']!,
          _metadataEditedMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('scan_batch_id')) {
      context.handle(
        _scanBatchIdMeta,
        scanBatchId.isAcceptableOrUnknown(
          data['scan_batch_id']!,
          _scanBatchIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scanBatchIdMeta);
    }
    if (data.containsKey('scan_source')) {
      context.handle(
        _scanSourceMeta,
        scanSource.isAcceptableOrUnknown(data['scan_source']!, _scanSourceMeta),
      );
    } else if (isInserting) {
      context.missing(_scanSourceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSongRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSongRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      )!,
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      discNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disc_number'],
      ),
      trackNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_number'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      folderPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_path'],
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      bitrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bitrate'],
      ),
      sampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate'],
      ),
      hasArtwork: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}has_artwork'],
      )!,
      metadataEdited: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}metadata_edited'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      scanBatchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_batch_id'],
      )!,
      scanSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_at'],
      ),
    );
  }

  @override
  $LocalSongsTable createAlias(String alias) {
    return $LocalSongsTable(attachedDatabase, alias);
  }
}

class LocalSongRow extends DataClass implements Insertable<LocalSongRow> {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final int? year;
  final int? discNumber;
  final int? trackNumber;
  final int durationMs;
  final String filePath;
  final String? folderPath;
  final int fileSize;
  final String mimeType;
  final int? bitrate;
  final int? sampleRate;
  final int hasArtwork;
  final int metadataEdited;
  final String status;
  final String scanBatchId;
  final String scanSource;
  final int createdAt;
  final int updatedAt;
  final int? modifiedAt;
  const LocalSongRow({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    this.year,
    this.discNumber,
    this.trackNumber,
    required this.durationMs,
    required this.filePath,
    this.folderPath,
    required this.fileSize,
    required this.mimeType,
    this.bitrate,
    this.sampleRate,
    required this.hasArtwork,
    required this.metadataEdited,
    required this.status,
    required this.scanBatchId,
    required this.scanSource,
    required this.createdAt,
    required this.updatedAt,
    this.modifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['album'] = Variable<String>(album);
    map['genre'] = Variable<String>(genre);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || discNumber != null) {
      map['disc_number'] = Variable<int>(discNumber);
    }
    if (!nullToAbsent || trackNumber != null) {
      map['track_number'] = Variable<int>(trackNumber);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || folderPath != null) {
      map['folder_path'] = Variable<String>(folderPath);
    }
    map['file_size'] = Variable<int>(fileSize);
    map['mime_type'] = Variable<String>(mimeType);
    if (!nullToAbsent || bitrate != null) {
      map['bitrate'] = Variable<int>(bitrate);
    }
    if (!nullToAbsent || sampleRate != null) {
      map['sample_rate'] = Variable<int>(sampleRate);
    }
    map['has_artwork'] = Variable<int>(hasArtwork);
    map['metadata_edited'] = Variable<int>(metadataEdited);
    map['status'] = Variable<String>(status);
    map['scan_batch_id'] = Variable<String>(scanBatchId);
    map['scan_source'] = Variable<String>(scanSource);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || modifiedAt != null) {
      map['modified_at'] = Variable<int>(modifiedAt);
    }
    return map;
  }

  LocalSongsCompanion toCompanion(bool nullToAbsent) {
    return LocalSongsCompanion(
      id: Value(id),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      genre: Value(genre),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      discNumber: discNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(discNumber),
      trackNumber: trackNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(trackNumber),
      durationMs: Value(durationMs),
      filePath: Value(filePath),
      folderPath: folderPath == null && nullToAbsent
          ? const Value.absent()
          : Value(folderPath),
      fileSize: Value(fileSize),
      mimeType: Value(mimeType),
      bitrate: bitrate == null && nullToAbsent
          ? const Value.absent()
          : Value(bitrate),
      sampleRate: sampleRate == null && nullToAbsent
          ? const Value.absent()
          : Value(sampleRate),
      hasArtwork: Value(hasArtwork),
      metadataEdited: Value(metadataEdited),
      status: Value(status),
      scanBatchId: Value(scanBatchId),
      scanSource: Value(scanSource),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      modifiedAt: modifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(modifiedAt),
    );
  }

  factory LocalSongRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSongRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String>(json['album']),
      genre: serializer.fromJson<String>(json['genre']),
      year: serializer.fromJson<int?>(json['year']),
      discNumber: serializer.fromJson<int?>(json['discNumber']),
      trackNumber: serializer.fromJson<int?>(json['trackNumber']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      filePath: serializer.fromJson<String>(json['filePath']),
      folderPath: serializer.fromJson<String?>(json['folderPath']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      bitrate: serializer.fromJson<int?>(json['bitrate']),
      sampleRate: serializer.fromJson<int?>(json['sampleRate']),
      hasArtwork: serializer.fromJson<int>(json['hasArtwork']),
      metadataEdited: serializer.fromJson<int>(json['metadataEdited']),
      status: serializer.fromJson<String>(json['status']),
      scanBatchId: serializer.fromJson<String>(json['scanBatchId']),
      scanSource: serializer.fromJson<String>(json['scanSource']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      modifiedAt: serializer.fromJson<int?>(json['modifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String>(album),
      'genre': serializer.toJson<String>(genre),
      'year': serializer.toJson<int?>(year),
      'discNumber': serializer.toJson<int?>(discNumber),
      'trackNumber': serializer.toJson<int?>(trackNumber),
      'durationMs': serializer.toJson<int>(durationMs),
      'filePath': serializer.toJson<String>(filePath),
      'folderPath': serializer.toJson<String?>(folderPath),
      'fileSize': serializer.toJson<int>(fileSize),
      'mimeType': serializer.toJson<String>(mimeType),
      'bitrate': serializer.toJson<int?>(bitrate),
      'sampleRate': serializer.toJson<int?>(sampleRate),
      'hasArtwork': serializer.toJson<int>(hasArtwork),
      'metadataEdited': serializer.toJson<int>(metadataEdited),
      'status': serializer.toJson<String>(status),
      'scanBatchId': serializer.toJson<String>(scanBatchId),
      'scanSource': serializer.toJson<String>(scanSource),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'modifiedAt': serializer.toJson<int?>(modifiedAt),
    };
  }

  LocalSongRow copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? genre,
    Value<int?> year = const Value.absent(),
    Value<int?> discNumber = const Value.absent(),
    Value<int?> trackNumber = const Value.absent(),
    int? durationMs,
    String? filePath,
    Value<String?> folderPath = const Value.absent(),
    int? fileSize,
    String? mimeType,
    Value<int?> bitrate = const Value.absent(),
    Value<int?> sampleRate = const Value.absent(),
    int? hasArtwork,
    int? metadataEdited,
    String? status,
    String? scanBatchId,
    String? scanSource,
    int? createdAt,
    int? updatedAt,
    Value<int?> modifiedAt = const Value.absent(),
  }) => LocalSongRow(
    id: id ?? this.id,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    genre: genre ?? this.genre,
    year: year.present ? year.value : this.year,
    discNumber: discNumber.present ? discNumber.value : this.discNumber,
    trackNumber: trackNumber.present ? trackNumber.value : this.trackNumber,
    durationMs: durationMs ?? this.durationMs,
    filePath: filePath ?? this.filePath,
    folderPath: folderPath.present ? folderPath.value : this.folderPath,
    fileSize: fileSize ?? this.fileSize,
    mimeType: mimeType ?? this.mimeType,
    bitrate: bitrate.present ? bitrate.value : this.bitrate,
    sampleRate: sampleRate.present ? sampleRate.value : this.sampleRate,
    hasArtwork: hasArtwork ?? this.hasArtwork,
    metadataEdited: metadataEdited ?? this.metadataEdited,
    status: status ?? this.status,
    scanBatchId: scanBatchId ?? this.scanBatchId,
    scanSource: scanSource ?? this.scanSource,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    modifiedAt: modifiedAt.present ? modifiedAt.value : this.modifiedAt,
  );
  LocalSongRow copyWithCompanion(LocalSongsCompanion data) {
    return LocalSongRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      genre: data.genre.present ? data.genre.value : this.genre,
      year: data.year.present ? data.year.value : this.year,
      discNumber: data.discNumber.present
          ? data.discNumber.value
          : this.discNumber,
      trackNumber: data.trackNumber.present
          ? data.trackNumber.value
          : this.trackNumber,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      folderPath: data.folderPath.present
          ? data.folderPath.value
          : this.folderPath,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      bitrate: data.bitrate.present ? data.bitrate.value : this.bitrate,
      sampleRate: data.sampleRate.present
          ? data.sampleRate.value
          : this.sampleRate,
      hasArtwork: data.hasArtwork.present
          ? data.hasArtwork.value
          : this.hasArtwork,
      metadataEdited: data.metadataEdited.present
          ? data.metadataEdited.value
          : this.metadataEdited,
      status: data.status.present ? data.status.value : this.status,
      scanBatchId: data.scanBatchId.present
          ? data.scanBatchId.value
          : this.scanBatchId,
      scanSource: data.scanSource.present
          ? data.scanSource.value
          : this.scanSource,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSongRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('discNumber: $discNumber, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('durationMs: $durationMs, ')
          ..write('filePath: $filePath, ')
          ..write('folderPath: $folderPath, ')
          ..write('fileSize: $fileSize, ')
          ..write('mimeType: $mimeType, ')
          ..write('bitrate: $bitrate, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('hasArtwork: $hasArtwork, ')
          ..write('metadataEdited: $metadataEdited, ')
          ..write('status: $status, ')
          ..write('scanBatchId: $scanBatchId, ')
          ..write('scanSource: $scanSource, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('modifiedAt: $modifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    artist,
    album,
    genre,
    year,
    discNumber,
    trackNumber,
    durationMs,
    filePath,
    folderPath,
    fileSize,
    mimeType,
    bitrate,
    sampleRate,
    hasArtwork,
    metadataEdited,
    status,
    scanBatchId,
    scanSource,
    createdAt,
    updatedAt,
    modifiedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSongRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.genre == this.genre &&
          other.year == this.year &&
          other.discNumber == this.discNumber &&
          other.trackNumber == this.trackNumber &&
          other.durationMs == this.durationMs &&
          other.filePath == this.filePath &&
          other.folderPath == this.folderPath &&
          other.fileSize == this.fileSize &&
          other.mimeType == this.mimeType &&
          other.bitrate == this.bitrate &&
          other.sampleRate == this.sampleRate &&
          other.hasArtwork == this.hasArtwork &&
          other.metadataEdited == this.metadataEdited &&
          other.status == this.status &&
          other.scanBatchId == this.scanBatchId &&
          other.scanSource == this.scanSource &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.modifiedAt == this.modifiedAt);
}

class LocalSongsCompanion extends UpdateCompanion<LocalSongRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> artist;
  final Value<String> album;
  final Value<String> genre;
  final Value<int?> year;
  final Value<int?> discNumber;
  final Value<int?> trackNumber;
  final Value<int> durationMs;
  final Value<String> filePath;
  final Value<String?> folderPath;
  final Value<int> fileSize;
  final Value<String> mimeType;
  final Value<int?> bitrate;
  final Value<int?> sampleRate;
  final Value<int> hasArtwork;
  final Value<int> metadataEdited;
  final Value<String> status;
  final Value<String> scanBatchId;
  final Value<String> scanSource;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> modifiedAt;
  final Value<int> rowid;
  const LocalSongsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.filePath = const Value.absent(),
    this.folderPath = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.hasArtwork = const Value.absent(),
    this.metadataEdited = const Value.absent(),
    this.status = const Value.absent(),
    this.scanBatchId = const Value.absent(),
    this.scanSource = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSongsCompanion.insert({
    required String id,
    required String title,
    required String artist,
    required String album,
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.trackNumber = const Value.absent(),
    required int durationMs,
    required String filePath,
    this.folderPath = const Value.absent(),
    required int fileSize,
    required String mimeType,
    this.bitrate = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.hasArtwork = const Value.absent(),
    this.metadataEdited = const Value.absent(),
    this.status = const Value.absent(),
    required String scanBatchId,
    required String scanSource,
    required int createdAt,
    required int updatedAt,
    this.modifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       artist = Value(artist),
       album = Value(album),
       durationMs = Value(durationMs),
       filePath = Value(filePath),
       fileSize = Value(fileSize),
       mimeType = Value(mimeType),
       scanBatchId = Value(scanBatchId),
       scanSource = Value(scanSource),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalSongRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? genre,
    Expression<int>? year,
    Expression<int>? discNumber,
    Expression<int>? trackNumber,
    Expression<int>? durationMs,
    Expression<String>? filePath,
    Expression<String>? folderPath,
    Expression<int>? fileSize,
    Expression<String>? mimeType,
    Expression<int>? bitrate,
    Expression<int>? sampleRate,
    Expression<int>? hasArtwork,
    Expression<int>? metadataEdited,
    Expression<String>? status,
    Expression<String>? scanBatchId,
    Expression<String>? scanSource,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? modifiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (genre != null) 'genre': genre,
      if (year != null) 'year': year,
      if (discNumber != null) 'disc_number': discNumber,
      if (trackNumber != null) 'track_number': trackNumber,
      if (durationMs != null) 'duration_ms': durationMs,
      if (filePath != null) 'file_path': filePath,
      if (folderPath != null) 'folder_path': folderPath,
      if (fileSize != null) 'file_size': fileSize,
      if (mimeType != null) 'mime_type': mimeType,
      if (bitrate != null) 'bitrate': bitrate,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (hasArtwork != null) 'has_artwork': hasArtwork,
      if (metadataEdited != null) 'metadata_edited': metadataEdited,
      if (status != null) 'status': status,
      if (scanBatchId != null) 'scan_batch_id': scanBatchId,
      if (scanSource != null) 'scan_source': scanSource,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSongsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? artist,
    Value<String>? album,
    Value<String>? genre,
    Value<int?>? year,
    Value<int?>? discNumber,
    Value<int?>? trackNumber,
    Value<int>? durationMs,
    Value<String>? filePath,
    Value<String?>? folderPath,
    Value<int>? fileSize,
    Value<String>? mimeType,
    Value<int?>? bitrate,
    Value<int?>? sampleRate,
    Value<int>? hasArtwork,
    Value<int>? metadataEdited,
    Value<String>? status,
    Value<String>? scanBatchId,
    Value<String>? scanSource,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? modifiedAt,
    Value<int>? rowid,
  }) {
    return LocalSongsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      discNumber: discNumber ?? this.discNumber,
      trackNumber: trackNumber ?? this.trackNumber,
      durationMs: durationMs ?? this.durationMs,
      filePath: filePath ?? this.filePath,
      folderPath: folderPath ?? this.folderPath,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      hasArtwork: hasArtwork ?? this.hasArtwork,
      metadataEdited: metadataEdited ?? this.metadataEdited,
      status: status ?? this.status,
      scanBatchId: scanBatchId ?? this.scanBatchId,
      scanSource: scanSource ?? this.scanSource,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (discNumber.present) {
      map['disc_number'] = Variable<int>(discNumber.value);
    }
    if (trackNumber.present) {
      map['track_number'] = Variable<int>(trackNumber.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (folderPath.present) {
      map['folder_path'] = Variable<String>(folderPath.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (bitrate.present) {
      map['bitrate'] = Variable<int>(bitrate.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (hasArtwork.present) {
      map['has_artwork'] = Variable<int>(hasArtwork.value);
    }
    if (metadataEdited.present) {
      map['metadata_edited'] = Variable<int>(metadataEdited.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (scanBatchId.present) {
      map['scan_batch_id'] = Variable<String>(scanBatchId.value);
    }
    if (scanSource.present) {
      map['scan_source'] = Variable<String>(scanSource.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<int>(modifiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSongsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('discNumber: $discNumber, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('durationMs: $durationMs, ')
          ..write('filePath: $filePath, ')
          ..write('folderPath: $folderPath, ')
          ..write('fileSize: $fileSize, ')
          ..write('mimeType: $mimeType, ')
          ..write('bitrate: $bitrate, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('hasArtwork: $hasArtwork, ')
          ..write('metadataEdited: $metadataEdited, ')
          ..write('status: $status, ')
          ..write('scanBatchId: $scanBatchId, ')
          ..write('scanSource: $scanSource, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayStatsTable extends PlayStats
    with TableInfo<$PlayStatsTable, PlayStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_songs (id)',
    ),
  );
  static const VerificationMeta _playCountMeta = const VerificationMeta(
    'playCount',
  );
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
    'play_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalDurationMsMeta = const VerificationMeta(
    'totalDurationMs',
  );
  @override
  late final GeneratedColumn<int> totalDurationMs = GeneratedColumn<int>(
    'total_duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<int> lastPlayedAt = GeneratedColumn<int>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    songId,
    playCount,
    totalDurationMs,
    lastPlayedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayStat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('play_count')) {
      context.handle(
        _playCountMeta,
        playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta),
      );
    }
    if (data.containsKey('total_duration_ms')) {
      context.handle(
        _totalDurationMsMeta,
        totalDurationMs.isAcceptableOrUnknown(
          data['total_duration_ms']!,
          _totalDurationMsMeta,
        ),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {songId};
  @override
  PlayStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayStat(
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      playCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_count'],
      )!,
      totalDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_duration_ms'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_played_at'],
      ),
    );
  }

  @override
  $PlayStatsTable createAlias(String alias) {
    return $PlayStatsTable(attachedDatabase, alias);
  }
}

class PlayStat extends DataClass implements Insertable<PlayStat> {
  final String songId;
  final int playCount;
  final int totalDurationMs;
  final int? lastPlayedAt;
  const PlayStat({
    required this.songId,
    required this.playCount,
    required this.totalDurationMs,
    this.lastPlayedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['song_id'] = Variable<String>(songId);
    map['play_count'] = Variable<int>(playCount);
    map['total_duration_ms'] = Variable<int>(totalDurationMs);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<int>(lastPlayedAt);
    }
    return map;
  }

  PlayStatsCompanion toCompanion(bool nullToAbsent) {
    return PlayStatsCompanion(
      songId: Value(songId),
      playCount: Value(playCount),
      totalDurationMs: Value(totalDurationMs),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
    );
  }

  factory PlayStat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayStat(
      songId: serializer.fromJson<String>(json['songId']),
      playCount: serializer.fromJson<int>(json['playCount']),
      totalDurationMs: serializer.fromJson<int>(json['totalDurationMs']),
      lastPlayedAt: serializer.fromJson<int?>(json['lastPlayedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'songId': serializer.toJson<String>(songId),
      'playCount': serializer.toJson<int>(playCount),
      'totalDurationMs': serializer.toJson<int>(totalDurationMs),
      'lastPlayedAt': serializer.toJson<int?>(lastPlayedAt),
    };
  }

  PlayStat copyWith({
    String? songId,
    int? playCount,
    int? totalDurationMs,
    Value<int?> lastPlayedAt = const Value.absent(),
  }) => PlayStat(
    songId: songId ?? this.songId,
    playCount: playCount ?? this.playCount,
    totalDurationMs: totalDurationMs ?? this.totalDurationMs,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
  );
  PlayStat copyWithCompanion(PlayStatsCompanion data) {
    return PlayStat(
      songId: data.songId.present ? data.songId.value : this.songId,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      totalDurationMs: data.totalDurationMs.present
          ? data.totalDurationMs.value
          : this.totalDurationMs,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayStat(')
          ..write('songId: $songId, ')
          ..write('playCount: $playCount, ')
          ..write('totalDurationMs: $totalDurationMs, ')
          ..write('lastPlayedAt: $lastPlayedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(songId, playCount, totalDurationMs, lastPlayedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayStat &&
          other.songId == this.songId &&
          other.playCount == this.playCount &&
          other.totalDurationMs == this.totalDurationMs &&
          other.lastPlayedAt == this.lastPlayedAt);
}

class PlayStatsCompanion extends UpdateCompanion<PlayStat> {
  final Value<String> songId;
  final Value<int> playCount;
  final Value<int> totalDurationMs;
  final Value<int?> lastPlayedAt;
  final Value<int> rowid;
  const PlayStatsCompanion({
    this.songId = const Value.absent(),
    this.playCount = const Value.absent(),
    this.totalDurationMs = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayStatsCompanion.insert({
    required String songId,
    this.playCount = const Value.absent(),
    this.totalDurationMs = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : songId = Value(songId);
  static Insertable<PlayStat> custom({
    Expression<String>? songId,
    Expression<int>? playCount,
    Expression<int>? totalDurationMs,
    Expression<int>? lastPlayedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (songId != null) 'song_id': songId,
      if (playCount != null) 'play_count': playCount,
      if (totalDurationMs != null) 'total_duration_ms': totalDurationMs,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayStatsCompanion copyWith({
    Value<String>? songId,
    Value<int>? playCount,
    Value<int>? totalDurationMs,
    Value<int?>? lastPlayedAt,
    Value<int>? rowid,
  }) {
    return PlayStatsCompanion(
      songId: songId ?? this.songId,
      playCount: playCount ?? this.playCount,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (totalDurationMs.present) {
      map['total_duration_ms'] = Variable<int>(totalDurationMs.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<int>(lastPlayedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayStatsCompanion(')
          ..write('songId: $songId, ')
          ..write('playCount: $playCount, ')
          ..write('totalDurationMs: $totalDurationMs, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScanFoldersTable extends ScanFolders
    with TableInfo<$ScanFoldersTable, ScanFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<int> enabled = GeneratedColumn<int>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _bookmarkMeta = const VerificationMeta(
    'bookmark',
  );
  @override
  late final GeneratedColumn<String> bookmark = GeneratedColumn<String>(
    'bookmark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, platform, path, enabled, bookmark];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('bookmark')) {
      context.handle(
        _bookmarkMeta,
        bookmark.isAcceptableOrUnknown(data['bookmark']!, _bookmarkMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {platform, path},
  ];
  @override
  ScanFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}enabled'],
      )!,
      bookmark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bookmark'],
      ),
    );
  }

  @override
  $ScanFoldersTable createAlias(String alias) {
    return $ScanFoldersTable(attachedDatabase, alias);
  }
}

class ScanFolder extends DataClass implements Insertable<ScanFolder> {
  final int id;
  final String platform;
  final String path;
  final int enabled;
  final String? bookmark;
  const ScanFolder({
    required this.id,
    required this.platform,
    required this.path,
    required this.enabled,
    this.bookmark,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['platform'] = Variable<String>(platform);
    map['path'] = Variable<String>(path);
    map['enabled'] = Variable<int>(enabled);
    if (!nullToAbsent || bookmark != null) {
      map['bookmark'] = Variable<String>(bookmark);
    }
    return map;
  }

  ScanFoldersCompanion toCompanion(bool nullToAbsent) {
    return ScanFoldersCompanion(
      id: Value(id),
      platform: Value(platform),
      path: Value(path),
      enabled: Value(enabled),
      bookmark: bookmark == null && nullToAbsent
          ? const Value.absent()
          : Value(bookmark),
    );
  }

  factory ScanFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanFolder(
      id: serializer.fromJson<int>(json['id']),
      platform: serializer.fromJson<String>(json['platform']),
      path: serializer.fromJson<String>(json['path']),
      enabled: serializer.fromJson<int>(json['enabled']),
      bookmark: serializer.fromJson<String?>(json['bookmark']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'platform': serializer.toJson<String>(platform),
      'path': serializer.toJson<String>(path),
      'enabled': serializer.toJson<int>(enabled),
      'bookmark': serializer.toJson<String?>(bookmark),
    };
  }

  ScanFolder copyWith({
    int? id,
    String? platform,
    String? path,
    int? enabled,
    Value<String?> bookmark = const Value.absent(),
  }) => ScanFolder(
    id: id ?? this.id,
    platform: platform ?? this.platform,
    path: path ?? this.path,
    enabled: enabled ?? this.enabled,
    bookmark: bookmark.present ? bookmark.value : this.bookmark,
  );
  ScanFolder copyWithCompanion(ScanFoldersCompanion data) {
    return ScanFolder(
      id: data.id.present ? data.id.value : this.id,
      platform: data.platform.present ? data.platform.value : this.platform,
      path: data.path.present ? data.path.value : this.path,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      bookmark: data.bookmark.present ? data.bookmark.value : this.bookmark,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanFolder(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('path: $path, ')
          ..write('enabled: $enabled, ')
          ..write('bookmark: $bookmark')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, platform, path, enabled, bookmark);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanFolder &&
          other.id == this.id &&
          other.platform == this.platform &&
          other.path == this.path &&
          other.enabled == this.enabled &&
          other.bookmark == this.bookmark);
}

class ScanFoldersCompanion extends UpdateCompanion<ScanFolder> {
  final Value<int> id;
  final Value<String> platform;
  final Value<String> path;
  final Value<int> enabled;
  final Value<String?> bookmark;
  const ScanFoldersCompanion({
    this.id = const Value.absent(),
    this.platform = const Value.absent(),
    this.path = const Value.absent(),
    this.enabled = const Value.absent(),
    this.bookmark = const Value.absent(),
  });
  ScanFoldersCompanion.insert({
    this.id = const Value.absent(),
    required String platform,
    required String path,
    this.enabled = const Value.absent(),
    this.bookmark = const Value.absent(),
  }) : platform = Value(platform),
       path = Value(path);
  static Insertable<ScanFolder> custom({
    Expression<int>? id,
    Expression<String>? platform,
    Expression<String>? path,
    Expression<int>? enabled,
    Expression<String>? bookmark,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (platform != null) 'platform': platform,
      if (path != null) 'path': path,
      if (enabled != null) 'enabled': enabled,
      if (bookmark != null) 'bookmark': bookmark,
    });
  }

  ScanFoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? platform,
    Value<String>? path,
    Value<int>? enabled,
    Value<String?>? bookmark,
  }) {
    return ScanFoldersCompanion(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      path: path ?? this.path,
      enabled: enabled ?? this.enabled,
      bookmark: bookmark ?? this.bookmark,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<int>(enabled.value);
    }
    if (bookmark.present) {
      map['bookmark'] = Variable<String>(bookmark.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanFoldersCompanion(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('path: $path, ')
          ..write('enabled: $enabled, ')
          ..write('bookmark: $bookmark')
          ..write(')'))
        .toString();
  }
}

class $ArtistsTable extends Artists with TableInfo<$ArtistsTable, Artist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Artist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name},
  ];
  @override
  Artist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Artist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $ArtistsTable createAlias(String alias) {
    return $ArtistsTable(attachedDatabase, alias);
  }
}

class Artist extends DataClass implements Insertable<Artist> {
  final int id;
  final String name;
  const Artist({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  ArtistsCompanion toCompanion(bool nullToAbsent) {
    return ArtistsCompanion(id: Value(id), name: Value(name));
  }

  factory Artist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Artist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Artist copyWith({int? id, String? name}) =>
      Artist(id: id ?? this.id, name: name ?? this.name);
  Artist copyWithCompanion(ArtistsCompanion data) {
    return Artist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Artist(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Artist && other.id == this.id && other.name == this.name);
}

class ArtistsCompanion extends UpdateCompanion<Artist> {
  final Value<int> id;
  final Value<String> name;
  const ArtistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  ArtistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<Artist> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  ArtistsCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return ArtistsCompanion(id: id ?? this.id, name: name ?? this.name);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $SongArtistsTable extends SongArtists
    with TableInfo<$SongArtistsTable, SongArtist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_songs (id)',
    ),
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<int> artistId = GeneratedColumn<int>(
    'artist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES artists (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, songId, artistId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'song_artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<SongArtist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {songId, artistId},
  ];
  @override
  SongArtist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongArtist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      artistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}artist_id'],
      )!,
    );
  }

  @override
  $SongArtistsTable createAlias(String alias) {
    return $SongArtistsTable(attachedDatabase, alias);
  }
}

class SongArtist extends DataClass implements Insertable<SongArtist> {
  final int id;
  final String songId;
  final int artistId;
  const SongArtist({
    required this.id,
    required this.songId,
    required this.artistId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['song_id'] = Variable<String>(songId);
    map['artist_id'] = Variable<int>(artistId);
    return map;
  }

  SongArtistsCompanion toCompanion(bool nullToAbsent) {
    return SongArtistsCompanion(
      id: Value(id),
      songId: Value(songId),
      artistId: Value(artistId),
    );
  }

  factory SongArtist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongArtist(
      id: serializer.fromJson<int>(json['id']),
      songId: serializer.fromJson<String>(json['songId']),
      artistId: serializer.fromJson<int>(json['artistId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'songId': serializer.toJson<String>(songId),
      'artistId': serializer.toJson<int>(artistId),
    };
  }

  SongArtist copyWith({int? id, String? songId, int? artistId}) => SongArtist(
    id: id ?? this.id,
    songId: songId ?? this.songId,
    artistId: artistId ?? this.artistId,
  );
  SongArtist copyWithCompanion(SongArtistsCompanion data) {
    return SongArtist(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongArtist(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('artistId: $artistId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, songId, artistId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongArtist &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.artistId == this.artistId);
}

class SongArtistsCompanion extends UpdateCompanion<SongArtist> {
  final Value<int> id;
  final Value<String> songId;
  final Value<int> artistId;
  const SongArtistsCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.artistId = const Value.absent(),
  });
  SongArtistsCompanion.insert({
    this.id = const Value.absent(),
    required String songId,
    required int artistId,
  }) : songId = Value(songId),
       artistId = Value(artistId);
  static Insertable<SongArtist> custom({
    Expression<int>? id,
    Expression<String>? songId,
    Expression<int>? artistId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (artistId != null) 'artist_id': artistId,
    });
  }

  SongArtistsCompanion copyWith({
    Value<int>? id,
    Value<String>? songId,
    Value<int>? artistId,
  }) {
    return SongArtistsCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      artistId: artistId ?? this.artistId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<int>(artistId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongArtistsCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('artistId: $artistId')
          ..write(')'))
        .toString();
  }
}

class $PlaybackQueuesTable extends PlaybackQueues
    with TableInfo<$PlaybackQueuesTable, PlaybackQueue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackQueuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [slot, metadata];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_queues';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackQueue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    } else if (isInserting) {
      context.missing(_metadataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slot};
  @override
  PlaybackQueue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackQueue(
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
    );
  }

  @override
  $PlaybackQueuesTable createAlias(String alias) {
    return $PlaybackQueuesTable(attachedDatabase, alias);
  }
}

class PlaybackQueue extends DataClass implements Insertable<PlaybackQueue> {
  final String slot;
  final String metadata;
  const PlaybackQueue({required this.slot, required this.metadata});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slot'] = Variable<String>(slot);
    map['metadata'] = Variable<String>(metadata);
    return map;
  }

  PlaybackQueuesCompanion toCompanion(bool nullToAbsent) {
    return PlaybackQueuesCompanion(
      slot: Value(slot),
      metadata: Value(metadata),
    );
  }

  factory PlaybackQueue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackQueue(
      slot: serializer.fromJson<String>(json['slot']),
      metadata: serializer.fromJson<String>(json['metadata']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slot': serializer.toJson<String>(slot),
      'metadata': serializer.toJson<String>(metadata),
    };
  }

  PlaybackQueue copyWith({String? slot, String? metadata}) => PlaybackQueue(
    slot: slot ?? this.slot,
    metadata: metadata ?? this.metadata,
  );
  PlaybackQueue copyWithCompanion(PlaybackQueuesCompanion data) {
    return PlaybackQueue(
      slot: data.slot.present ? data.slot.value : this.slot,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackQueue(')
          ..write('slot: $slot, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(slot, metadata);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackQueue &&
          other.slot == this.slot &&
          other.metadata == this.metadata);
}

class PlaybackQueuesCompanion extends UpdateCompanion<PlaybackQueue> {
  final Value<String> slot;
  final Value<String> metadata;
  final Value<int> rowid;
  const PlaybackQueuesCompanion({
    this.slot = const Value.absent(),
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackQueuesCompanion.insert({
    required String slot,
    required String metadata,
    this.rowid = const Value.absent(),
  }) : slot = Value(slot),
       metadata = Value(metadata);
  static Insertable<PlaybackQueue> custom({
    Expression<String>? slot,
    Expression<String>? metadata,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (slot != null) 'slot': slot,
      if (metadata != null) 'metadata': metadata,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackQueuesCompanion copyWith({
    Value<String>? slot,
    Value<String>? metadata,
    Value<int>? rowid,
  }) {
    return PlaybackQueuesCompanion(
      slot: slot ?? this.slot,
      metadata: metadata ?? this.metadata,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackQueuesCompanion(')
          ..write('slot: $slot, ')
          ..write('metadata: $metadata, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackQueueEntriesTable extends PlaybackQueueEntries
    with TableInfo<$PlaybackQueueEntriesTable, PlaybackQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackQueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playback_queues (slot) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [slot, position, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_queue_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackQueueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slot, position};
  @override
  PlaybackQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackQueueEntry(
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $PlaybackQueueEntriesTable createAlias(String alias) {
    return $PlaybackQueueEntriesTable(attachedDatabase, alias);
  }
}

class PlaybackQueueEntry extends DataClass
    implements Insertable<PlaybackQueueEntry> {
  final String slot;
  final int position;
  final String payload;
  const PlaybackQueueEntry({
    required this.slot,
    required this.position,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slot'] = Variable<String>(slot);
    map['position'] = Variable<int>(position);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  PlaybackQueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return PlaybackQueueEntriesCompanion(
      slot: Value(slot),
      position: Value(position),
      payload: Value(payload),
    );
  }

  factory PlaybackQueueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackQueueEntry(
      slot: serializer.fromJson<String>(json['slot']),
      position: serializer.fromJson<int>(json['position']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slot': serializer.toJson<String>(slot),
      'position': serializer.toJson<int>(position),
      'payload': serializer.toJson<String>(payload),
    };
  }

  PlaybackQueueEntry copyWith({String? slot, int? position, String? payload}) =>
      PlaybackQueueEntry(
        slot: slot ?? this.slot,
        position: position ?? this.position,
        payload: payload ?? this.payload,
      );
  PlaybackQueueEntry copyWithCompanion(PlaybackQueueEntriesCompanion data) {
    return PlaybackQueueEntry(
      slot: data.slot.present ? data.slot.value : this.slot,
      position: data.position.present ? data.position.value : this.position,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackQueueEntry(')
          ..write('slot: $slot, ')
          ..write('position: $position, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(slot, position, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackQueueEntry &&
          other.slot == this.slot &&
          other.position == this.position &&
          other.payload == this.payload);
}

class PlaybackQueueEntriesCompanion
    extends UpdateCompanion<PlaybackQueueEntry> {
  final Value<String> slot;
  final Value<int> position;
  final Value<String> payload;
  final Value<int> rowid;
  const PlaybackQueueEntriesCompanion({
    this.slot = const Value.absent(),
    this.position = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackQueueEntriesCompanion.insert({
    required String slot,
    required int position,
    required String payload,
    this.rowid = const Value.absent(),
  }) : slot = Value(slot),
       position = Value(position),
       payload = Value(payload);
  static Insertable<PlaybackQueueEntry> custom({
    Expression<String>? slot,
    Expression<int>? position,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (slot != null) 'slot': slot,
      if (position != null) 'position': position,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackQueueEntriesCompanion copyWith({
    Value<String>? slot,
    Value<int>? position,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return PlaybackQueueEntriesCompanion(
      slot: slot ?? this.slot,
      position: position ?? this.position,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackQueueEntriesCompanion(')
          ..write('slot: $slot, ')
          ..write('position: $position, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackHistoryTable extends PlaybackHistory
    with TableInfo<$PlaybackHistoryTable, PlaybackHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackKeyMeta = const VerificationMeta(
    'trackKey',
  );
  @override
  late final GeneratedColumn<String> trackKey = GeneratedColumn<String>(
    'track_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<int> playedAt = GeneratedColumn<int>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [trackKey, playedAt, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_key')) {
      context.handle(
        _trackKeyMeta,
        trackKey.isAcceptableOrUnknown(data['track_key']!, _trackKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_trackKeyMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackKey};
  @override
  PlaybackHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackHistoryData(
      trackKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_key'],
      )!,
      playedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}played_at'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $PlaybackHistoryTable createAlias(String alias) {
    return $PlaybackHistoryTable(attachedDatabase, alias);
  }
}

class PlaybackHistoryData extends DataClass
    implements Insertable<PlaybackHistoryData> {
  final String trackKey;
  final int playedAt;
  final String payload;
  const PlaybackHistoryData({
    required this.trackKey,
    required this.playedAt,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_key'] = Variable<String>(trackKey);
    map['played_at'] = Variable<int>(playedAt);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  PlaybackHistoryCompanion toCompanion(bool nullToAbsent) {
    return PlaybackHistoryCompanion(
      trackKey: Value(trackKey),
      playedAt: Value(playedAt),
      payload: Value(payload),
    );
  }

  factory PlaybackHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackHistoryData(
      trackKey: serializer.fromJson<String>(json['trackKey']),
      playedAt: serializer.fromJson<int>(json['playedAt']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackKey': serializer.toJson<String>(trackKey),
      'playedAt': serializer.toJson<int>(playedAt),
      'payload': serializer.toJson<String>(payload),
    };
  }

  PlaybackHistoryData copyWith({
    String? trackKey,
    int? playedAt,
    String? payload,
  }) => PlaybackHistoryData(
    trackKey: trackKey ?? this.trackKey,
    playedAt: playedAt ?? this.playedAt,
    payload: payload ?? this.payload,
  );
  PlaybackHistoryData copyWithCompanion(PlaybackHistoryCompanion data) {
    return PlaybackHistoryData(
      trackKey: data.trackKey.present ? data.trackKey.value : this.trackKey,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackHistoryData(')
          ..write('trackKey: $trackKey, ')
          ..write('playedAt: $playedAt, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackKey, playedAt, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackHistoryData &&
          other.trackKey == this.trackKey &&
          other.playedAt == this.playedAt &&
          other.payload == this.payload);
}

class PlaybackHistoryCompanion extends UpdateCompanion<PlaybackHistoryData> {
  final Value<String> trackKey;
  final Value<int> playedAt;
  final Value<String> payload;
  final Value<int> rowid;
  const PlaybackHistoryCompanion({
    this.trackKey = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackHistoryCompanion.insert({
    required String trackKey,
    required int playedAt,
    required String payload,
    this.rowid = const Value.absent(),
  }) : trackKey = Value(trackKey),
       playedAt = Value(playedAt),
       payload = Value(payload);
  static Insertable<PlaybackHistoryData> custom({
    Expression<String>? trackKey,
    Expression<int>? playedAt,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackKey != null) 'track_key': trackKey,
      if (playedAt != null) 'played_at': playedAt,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackHistoryCompanion copyWith({
    Value<String>? trackKey,
    Value<int>? playedAt,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return PlaybackHistoryCompanion(
      trackKey: trackKey ?? this.trackKey,
      playedAt: playedAt ?? this.playedAt,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackKey.present) {
      map['track_key'] = Variable<String>(trackKey.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<int>(playedAt.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackHistoryCompanion(')
          ..write('trackKey: $trackKey, ')
          ..write('playedAt: $playedAt, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredDownloadTasksTable extends StoredDownloadTasks
    with TableInfo<$StoredDownloadTasksTable, StoredDownloadTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredDownloadTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [taskId, updatedAt, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stored_download_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredDownloadTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId};
  @override
  StoredDownloadTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredDownloadTask(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $StoredDownloadTasksTable createAlias(String alias) {
    return $StoredDownloadTasksTable(attachedDatabase, alias);
  }
}

class StoredDownloadTask extends DataClass
    implements Insertable<StoredDownloadTask> {
  final String taskId;
  final int updatedAt;
  final String payload;
  const StoredDownloadTask({
    required this.taskId,
    required this.updatedAt,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<String>(taskId);
    map['updated_at'] = Variable<int>(updatedAt);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  StoredDownloadTasksCompanion toCompanion(bool nullToAbsent) {
    return StoredDownloadTasksCompanion(
      taskId: Value(taskId),
      updatedAt: Value(updatedAt),
      payload: Value(payload),
    );
  }

  factory StoredDownloadTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredDownloadTask(
      taskId: serializer.fromJson<String>(json['taskId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<String>(taskId),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'payload': serializer.toJson<String>(payload),
    };
  }

  StoredDownloadTask copyWith({
    String? taskId,
    int? updatedAt,
    String? payload,
  }) => StoredDownloadTask(
    taskId: taskId ?? this.taskId,
    updatedAt: updatedAt ?? this.updatedAt,
    payload: payload ?? this.payload,
  );
  StoredDownloadTask copyWithCompanion(StoredDownloadTasksCompanion data) {
    return StoredDownloadTask(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredDownloadTask(')
          ..write('taskId: $taskId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(taskId, updatedAt, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredDownloadTask &&
          other.taskId == this.taskId &&
          other.updatedAt == this.updatedAt &&
          other.payload == this.payload);
}

class StoredDownloadTasksCompanion extends UpdateCompanion<StoredDownloadTask> {
  final Value<String> taskId;
  final Value<int> updatedAt;
  final Value<String> payload;
  final Value<int> rowid;
  const StoredDownloadTasksCompanion({
    this.taskId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredDownloadTasksCompanion.insert({
    required String taskId,
    required int updatedAt,
    required String payload,
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       updatedAt = Value(updatedAt),
       payload = Value(payload);
  static Insertable<StoredDownloadTask> custom({
    Expression<String>? taskId,
    Expression<int>? updatedAt,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredDownloadTasksCompanion copyWith({
    Value<String>? taskId,
    Value<int>? updatedAt,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return StoredDownloadTasksCompanion(
      taskId: taskId ?? this.taskId,
      updatedAt: updatedAt ?? this.updatedAt,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredDownloadTasksCompanion(')
          ..write('taskId: $taskId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedFavoriteSongsTable extends CachedFavoriteSongs
    with TableInfo<$CachedFavoriteSongsTable, CachedFavoriteSong> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedFavoriteSongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [platform, songId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_favorite_songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedFavoriteSong> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {platform, songId};
  @override
  CachedFavoriteSong map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedFavoriteSong(
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
    );
  }

  @override
  $CachedFavoriteSongsTable createAlias(String alias) {
    return $CachedFavoriteSongsTable(attachedDatabase, alias);
  }
}

class CachedFavoriteSong extends DataClass
    implements Insertable<CachedFavoriteSong> {
  final String platform;
  final String songId;
  const CachedFavoriteSong({required this.platform, required this.songId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['platform'] = Variable<String>(platform);
    map['song_id'] = Variable<String>(songId);
    return map;
  }

  CachedFavoriteSongsCompanion toCompanion(bool nullToAbsent) {
    return CachedFavoriteSongsCompanion(
      platform: Value(platform),
      songId: Value(songId),
    );
  }

  factory CachedFavoriteSong.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedFavoriteSong(
      platform: serializer.fromJson<String>(json['platform']),
      songId: serializer.fromJson<String>(json['songId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'platform': serializer.toJson<String>(platform),
      'songId': serializer.toJson<String>(songId),
    };
  }

  CachedFavoriteSong copyWith({String? platform, String? songId}) =>
      CachedFavoriteSong(
        platform: platform ?? this.platform,
        songId: songId ?? this.songId,
      );
  CachedFavoriteSong copyWithCompanion(CachedFavoriteSongsCompanion data) {
    return CachedFavoriteSong(
      platform: data.platform.present ? data.platform.value : this.platform,
      songId: data.songId.present ? data.songId.value : this.songId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedFavoriteSong(')
          ..write('platform: $platform, ')
          ..write('songId: $songId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(platform, songId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedFavoriteSong &&
          other.platform == this.platform &&
          other.songId == this.songId);
}

class CachedFavoriteSongsCompanion extends UpdateCompanion<CachedFavoriteSong> {
  final Value<String> platform;
  final Value<String> songId;
  final Value<int> rowid;
  const CachedFavoriteSongsCompanion({
    this.platform = const Value.absent(),
    this.songId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedFavoriteSongsCompanion.insert({
    required String platform,
    required String songId,
    this.rowid = const Value.absent(),
  }) : platform = Value(platform),
       songId = Value(songId);
  static Insertable<CachedFavoriteSong> custom({
    Expression<String>? platform,
    Expression<String>? songId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (platform != null) 'platform': platform,
      if (songId != null) 'song_id': songId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedFavoriteSongsCompanion copyWith({
    Value<String>? platform,
    Value<String>? songId,
    Value<int>? rowid,
  }) {
    return CachedFavoriteSongsCompanion(
      platform: platform ?? this.platform,
      songId: songId ?? this.songId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedFavoriteSongsCompanion(')
          ..write('platform: $platform, ')
          ..write('songId: $songId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StorageMigrationsTable extends StorageMigrations
    with TableInfo<$StorageMigrationsTable, StorageMigration> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StorageMigrationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _storageKeyMeta = const VerificationMeta(
    'storageKey',
  );
  @override
  late final GeneratedColumn<String> storageKey = GeneratedColumn<String>(
    'storage_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [storageKey];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'storage_migrations';
  @override
  VerificationContext validateIntegrity(
    Insertable<StorageMigration> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('storage_key')) {
      context.handle(
        _storageKeyMeta,
        storageKey.isAcceptableOrUnknown(data['storage_key']!, _storageKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_storageKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {storageKey};
  @override
  StorageMigration map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StorageMigration(
      storageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_key'],
      )!,
    );
  }

  @override
  $StorageMigrationsTable createAlias(String alias) {
    return $StorageMigrationsTable(attachedDatabase, alias);
  }
}

class StorageMigration extends DataClass
    implements Insertable<StorageMigration> {
  final String storageKey;
  const StorageMigration({required this.storageKey});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['storage_key'] = Variable<String>(storageKey);
    return map;
  }

  StorageMigrationsCompanion toCompanion(bool nullToAbsent) {
    return StorageMigrationsCompanion(storageKey: Value(storageKey));
  }

  factory StorageMigration.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StorageMigration(
      storageKey: serializer.fromJson<String>(json['storageKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'storageKey': serializer.toJson<String>(storageKey),
    };
  }

  StorageMigration copyWith({String? storageKey}) =>
      StorageMigration(storageKey: storageKey ?? this.storageKey);
  StorageMigration copyWithCompanion(StorageMigrationsCompanion data) {
    return StorageMigration(
      storageKey: data.storageKey.present
          ? data.storageKey.value
          : this.storageKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StorageMigration(')
          ..write('storageKey: $storageKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => storageKey.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StorageMigration && other.storageKey == this.storageKey);
}

class StorageMigrationsCompanion extends UpdateCompanion<StorageMigration> {
  final Value<String> storageKey;
  final Value<int> rowid;
  const StorageMigrationsCompanion({
    this.storageKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StorageMigrationsCompanion.insert({
    required String storageKey,
    this.rowid = const Value.absent(),
  }) : storageKey = Value(storageKey);
  static Insertable<StorageMigration> custom({
    Expression<String>? storageKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (storageKey != null) 'storage_key': storageKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StorageMigrationsCompanion copyWith({
    Value<String>? storageKey,
    Value<int>? rowid,
  }) {
    return StorageMigrationsCompanion(
      storageKey: storageKey ?? this.storageKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (storageKey.present) {
      map['storage_key'] = Variable<String>(storageKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StorageMigrationsCompanion(')
          ..write('storageKey: $storageKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalMusicDatabase extends GeneratedDatabase {
  _$LocalMusicDatabase(QueryExecutor e) : super(e);
  $LocalMusicDatabaseManager get managers => $LocalMusicDatabaseManager(this);
  late final $LocalSongsTable localSongs = $LocalSongsTable(this);
  late final $PlayStatsTable playStats = $PlayStatsTable(this);
  late final $ScanFoldersTable scanFolders = $ScanFoldersTable(this);
  late final $ArtistsTable artists = $ArtistsTable(this);
  late final $SongArtistsTable songArtists = $SongArtistsTable(this);
  late final $PlaybackQueuesTable playbackQueues = $PlaybackQueuesTable(this);
  late final $PlaybackQueueEntriesTable playbackQueueEntries =
      $PlaybackQueueEntriesTable(this);
  late final $PlaybackHistoryTable playbackHistory = $PlaybackHistoryTable(
    this,
  );
  late final $StoredDownloadTasksTable storedDownloadTasks =
      $StoredDownloadTasksTable(this);
  late final $CachedFavoriteSongsTable cachedFavoriteSongs =
      $CachedFavoriteSongsTable(this);
  late final $StorageMigrationsTable storageMigrations =
      $StorageMigrationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localSongs,
    playStats,
    scanFolders,
    artists,
    songArtists,
    playbackQueues,
    playbackQueueEntries,
    playbackHistory,
    storedDownloadTasks,
    cachedFavoriteSongs,
    storageMigrations,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playback_queues',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playback_queue_entries', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LocalSongsTableCreateCompanionBuilder =
    LocalSongsCompanion Function({
      required String id,
      required String title,
      required String artist,
      required String album,
      Value<String> genre,
      Value<int?> year,
      Value<int?> discNumber,
      Value<int?> trackNumber,
      required int durationMs,
      required String filePath,
      Value<String?> folderPath,
      required int fileSize,
      required String mimeType,
      Value<int?> bitrate,
      Value<int?> sampleRate,
      Value<int> hasArtwork,
      Value<int> metadataEdited,
      Value<String> status,
      required String scanBatchId,
      required String scanSource,
      required int createdAt,
      required int updatedAt,
      Value<int?> modifiedAt,
      Value<int> rowid,
    });
typedef $$LocalSongsTableUpdateCompanionBuilder =
    LocalSongsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> artist,
      Value<String> album,
      Value<String> genre,
      Value<int?> year,
      Value<int?> discNumber,
      Value<int?> trackNumber,
      Value<int> durationMs,
      Value<String> filePath,
      Value<String?> folderPath,
      Value<int> fileSize,
      Value<String> mimeType,
      Value<int?> bitrate,
      Value<int?> sampleRate,
      Value<int> hasArtwork,
      Value<int> metadataEdited,
      Value<String> status,
      Value<String> scanBatchId,
      Value<String> scanSource,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> modifiedAt,
      Value<int> rowid,
    });

final class $$LocalSongsTableReferences
    extends
        BaseReferences<_$LocalMusicDatabase, $LocalSongsTable, LocalSongRow> {
  $$LocalSongsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlayStatsTable, List<PlayStat>>
  _playStatsRefsTable(_$LocalMusicDatabase db) => MultiTypedResultKey.fromTable(
    db.playStats,
    aliasName: 'local_songs__id__play_stats__song_id',
  );

  $$PlayStatsTableProcessedTableManager get playStatsRefs {
    final manager = $$PlayStatsTableTableManager(
      $_db,
      $_db.playStats,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playStatsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SongArtistsTable, List<SongArtist>>
  _songArtistsRefsTable(_$LocalMusicDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.songArtists,
        aliasName: 'local_songs__id__song_artists__song_id',
      );

  $$SongArtistsTableProcessedTableManager get songArtistsRefs {
    final manager = $$SongArtistsTableTableManager(
      $_db,
      $_db.songArtists,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_songArtistsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalSongsTableFilterComposer
    extends Composer<_$LocalMusicDatabase, $LocalSongsTable> {
  $$LocalSongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitrate => $composableBuilder(
    column: $table.bitrate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hasArtwork => $composableBuilder(
    column: $table.hasArtwork,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get metadataEdited => $composableBuilder(
    column: $table.metadataEdited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanBatchId => $composableBuilder(
    column: $table.scanBatchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanSource => $composableBuilder(
    column: $table.scanSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playStatsRefs(
    Expression<bool> Function($$PlayStatsTableFilterComposer f) f,
  ) {
    final $$PlayStatsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playStats,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayStatsTableFilterComposer(
            $db: $db,
            $table: $db.playStats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> songArtistsRefs(
    Expression<bool> Function($$SongArtistsTableFilterComposer f) f,
  ) {
    final $$SongArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songArtists,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongArtistsTableFilterComposer(
            $db: $db,
            $table: $db.songArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalSongsTableOrderingComposer
    extends Composer<_$LocalMusicDatabase, $LocalSongsTable> {
  $$LocalSongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitrate => $composableBuilder(
    column: $table.bitrate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hasArtwork => $composableBuilder(
    column: $table.hasArtwork,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get metadataEdited => $composableBuilder(
    column: $table.metadataEdited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanBatchId => $composableBuilder(
    column: $table.scanBatchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanSource => $composableBuilder(
    column: $table.scanSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSongsTableAnnotationComposer
    extends Composer<_$LocalMusicDatabase, $LocalSongsTable> {
  $$LocalSongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get bitrate =>
      $composableBuilder(column: $table.bitrate, builder: (column) => column);

  GeneratedColumn<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hasArtwork => $composableBuilder(
    column: $table.hasArtwork,
    builder: (column) => column,
  );

  GeneratedColumn<int> get metadataEdited => $composableBuilder(
    column: $table.metadataEdited,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get scanBatchId => $composableBuilder(
    column: $table.scanBatchId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scanSource => $composableBuilder(
    column: $table.scanSource,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  Expression<T> playStatsRefs<T extends Object>(
    Expression<T> Function($$PlayStatsTableAnnotationComposer a) f,
  ) {
    final $$PlayStatsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playStats,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayStatsTableAnnotationComposer(
            $db: $db,
            $table: $db.playStats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> songArtistsRefs<T extends Object>(
    Expression<T> Function($$SongArtistsTableAnnotationComposer a) f,
  ) {
    final $$SongArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songArtists,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.songArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalSongsTableTableManager
    extends
        RootTableManager<
          _$LocalMusicDatabase,
          $LocalSongsTable,
          LocalSongRow,
          $$LocalSongsTableFilterComposer,
          $$LocalSongsTableOrderingComposer,
          $$LocalSongsTableAnnotationComposer,
          $$LocalSongsTableCreateCompanionBuilder,
          $$LocalSongsTableUpdateCompanionBuilder,
          (LocalSongRow, $$LocalSongsTableReferences),
          LocalSongRow,
          PrefetchHooks Function({bool playStatsRefs, bool songArtistsRefs})
        > {
  $$LocalSongsTableTableManager(_$LocalMusicDatabase db, $LocalSongsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String> album = const Value.absent(),
                Value<String> genre = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String?> folderPath = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int?> bitrate = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<int> hasArtwork = const Value.absent(),
                Value<int> metadataEdited = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> scanBatchId = const Value.absent(),
                Value<String> scanSource = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> modifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSongsCompanion(
                id: id,
                title: title,
                artist: artist,
                album: album,
                genre: genre,
                year: year,
                discNumber: discNumber,
                trackNumber: trackNumber,
                durationMs: durationMs,
                filePath: filePath,
                folderPath: folderPath,
                fileSize: fileSize,
                mimeType: mimeType,
                bitrate: bitrate,
                sampleRate: sampleRate,
                hasArtwork: hasArtwork,
                metadataEdited: metadataEdited,
                status: status,
                scanBatchId: scanBatchId,
                scanSource: scanSource,
                createdAt: createdAt,
                updatedAt: updatedAt,
                modifiedAt: modifiedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String artist,
                required String album,
                Value<String> genre = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                required int durationMs,
                required String filePath,
                Value<String?> folderPath = const Value.absent(),
                required int fileSize,
                required String mimeType,
                Value<int?> bitrate = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<int> hasArtwork = const Value.absent(),
                Value<int> metadataEdited = const Value.absent(),
                Value<String> status = const Value.absent(),
                required String scanBatchId,
                required String scanSource,
                required int createdAt,
                required int updatedAt,
                Value<int?> modifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSongsCompanion.insert(
                id: id,
                title: title,
                artist: artist,
                album: album,
                genre: genre,
                year: year,
                discNumber: discNumber,
                trackNumber: trackNumber,
                durationMs: durationMs,
                filePath: filePath,
                folderPath: folderPath,
                fileSize: fileSize,
                mimeType: mimeType,
                bitrate: bitrate,
                sampleRate: sampleRate,
                hasArtwork: hasArtwork,
                metadataEdited: metadataEdited,
                status: status,
                scanBatchId: scanBatchId,
                scanSource: scanSource,
                createdAt: createdAt,
                updatedAt: updatedAt,
                modifiedAt: modifiedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalSongsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({playStatsRefs = false, songArtistsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playStatsRefs) db.playStats,
                    if (songArtistsRefs) db.songArtists,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playStatsRefs)
                        await $_getPrefetchedData<
                          LocalSongRow,
                          $LocalSongsTable,
                          PlayStat
                        >(
                          currentTable: table,
                          referencedTable: $$LocalSongsTableReferences
                              ._playStatsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalSongsTableReferences(
                                db,
                                table,
                                p0,
                              ).playStatsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (songArtistsRefs)
                        await $_getPrefetchedData<
                          LocalSongRow,
                          $LocalSongsTable,
                          SongArtist
                        >(
                          currentTable: table,
                          referencedTable: $$LocalSongsTableReferences
                              ._songArtistsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalSongsTableReferences(
                                db,
                                table,
                                p0,
                              ).songArtistsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LocalSongsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalMusicDatabase,
      $LocalSongsTable,
      LocalSongRow,
      $$LocalSongsTableFilterComposer,
      $$LocalSongsTableOrderingComposer,
      $$LocalSongsTableAnnotationComposer,
      $$LocalSongsTableCreateCompanionBuilder,
      $$LocalSongsTableUpdateCompanionBuilder,
      (LocalSongRow, $$LocalSongsTableReferences),
      LocalSongRow,
      PrefetchHooks Function({bool playStatsRefs, bool songArtistsRefs})
    >;
typedef $$PlayStatsTableCreateCompanionBuilder =
    PlayStatsCompanion Function({
      required String songId,
      Value<int> playCount,
      Value<int> totalDurationMs,
      Value<int?> lastPlayedAt,
      Value<int> rowid,
    });
typedef $$PlayStatsTableUpdateCompanionBuilder =
    PlayStatsCompanion Function({
      Value<String> songId,
      Value<int> playCount,
      Value<int> totalDurationMs,
      Value<int?> lastPlayedAt,
      Value<int> rowid,
    });

final class $$PlayStatsTableReferences
    extends BaseReferences<_$LocalMusicDatabase, $PlayStatsTable, PlayStat> {
  $$PlayStatsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LocalSongsTable _songIdTable(_$LocalMusicDatabase db) =>
      db.localSongs.createAlias('play_stats__song_id__local_songs__id');

  $$LocalSongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<String>('song_id')!;

    final manager = $$LocalSongsTableTableManager(
      $_db,
      $_db.localSongs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlayStatsTableFilterComposer
    extends Composer<_$LocalMusicDatabase, $PlayStatsTable> {
  $$PlayStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalDurationMs => $composableBuilder(
    column: $table.totalDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalSongsTableFilterComposer get songId {
    final $$LocalSongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.localSongs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSongsTableFilterComposer(
            $db: $db,
            $table: $db.localSongs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayStatsTableOrderingComposer
    extends Composer<_$LocalMusicDatabase, $PlayStatsTable> {
  $$PlayStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalDurationMs => $composableBuilder(
    column: $table.totalDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalSongsTableOrderingComposer get songId {
    final $$LocalSongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.localSongs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSongsTableOrderingComposer(
            $db: $db,
            $table: $db.localSongs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayStatsTableAnnotationComposer
    extends Composer<_$LocalMusicDatabase, $PlayStatsTable> {
  $$PlayStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<int> get totalDurationMs => $composableBuilder(
    column: $table.totalDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );

  $$LocalSongsTableAnnotationComposer get songId {
    final $$LocalSongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.localSongs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSongsTableAnnotationComposer(
            $db: $db,
            $table: $db.localSongs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayStatsTableTableManager
    extends
        RootTableManager<
          _$LocalMusicDatabase,
          $PlayStatsTable,
          PlayStat,
          $$PlayStatsTableFilterComposer,
          $$PlayStatsTableOrderingComposer,
          $$PlayStatsTableAnnotationComposer,
          $$PlayStatsTableCreateCompanionBuilder,
          $$PlayStatsTableUpdateCompanionBuilder,
          (PlayStat, $$PlayStatsTableReferences),
          PlayStat,
          PrefetchHooks Function({bool songId})
        > {
  $$PlayStatsTableTableManager(_$LocalMusicDatabase db, $PlayStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> songId = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<int> totalDurationMs = const Value.absent(),
                Value<int?> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayStatsCompanion(
                songId: songId,
                playCount: playCount,
                totalDurationMs: totalDurationMs,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String songId,
                Value<int> playCount = const Value.absent(),
                Value<int> totalDurationMs = const Value.absent(),
                Value<int?> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayStatsCompanion.insert(
                songId: songId,
                playCount: playCount,
                totalDurationMs: totalDurationMs,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlayStatsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.songId,
                                referencedTable: $$PlayStatsTableReferences
                                    ._songIdTable(db),
                                referencedColumn: $$PlayStatsTableReferences
                                    ._songIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlayStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalMusicDatabase,
      $PlayStatsTable,
      PlayStat,
      $$PlayStatsTableFilterComposer,
      $$PlayStatsTableOrderingComposer,
      $$PlayStatsTableAnnotationComposer,
      $$PlayStatsTableCreateCompanionBuilder,
      $$PlayStatsTableUpdateCompanionBuilder,
      (PlayStat, $$PlayStatsTableReferences),
      PlayStat,
      PrefetchHooks Function({bool songId})
    >;
typedef $$ScanFoldersTableCreateCompanionBuilder =
    ScanFoldersCompanion Function({
      Value<int> id,
      required String platform,
      required String path,
      Value<int> enabled,
      Value<String?> bookmark,
    });
typedef $$ScanFoldersTableUpdateCompanionBuilder =
    ScanFoldersCompanion Function({
      Value<int> id,
      Value<String> platform,
      Value<String> path,
      Value<int> enabled,
      Value<String?> bookmark,
    });

class $$ScanFoldersTableFilterComposer
    extends Composer<_$LocalMusicDatabase, $ScanFoldersTable> {
  $$ScanFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookmark => $composableBuilder(
    column: $table.bookmark,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanFoldersTableOrderingComposer
    extends Composer<_$LocalMusicDatabase, $ScanFoldersTable> {
  $$ScanFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookmark => $composableBuilder(
    column: $table.bookmark,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanFoldersTableAnnotationComposer
    extends Composer<_$LocalMusicDatabase, $ScanFoldersTable> {
  $$ScanFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get bookmark =>
      $composableBuilder(column: $table.bookmark, builder: (column) => column);
}

class $$ScanFoldersTableTableManager
    extends
        RootTableManager<
          _$LocalMusicDatabase,
          $ScanFoldersTable,
          ScanFolder,
          $$ScanFoldersTableFilterComposer,
          $$ScanFoldersTableOrderingComposer,
          $$ScanFoldersTableAnnotationComposer,
          $$ScanFoldersTableCreateCompanionBuilder,
          $$ScanFoldersTableUpdateCompanionBuilder,
          (
            ScanFolder,
            BaseReferences<_$LocalMusicDatabase, $ScanFoldersTable, ScanFolder>,
          ),
          ScanFolder,
          PrefetchHooks Function()
        > {
  $$ScanFoldersTableTableManager(
    _$LocalMusicDatabase db,
    $ScanFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> enabled = const Value.absent(),
                Value<String?> bookmark = const Value.absent(),
              }) => ScanFoldersCompanion(
                id: id,
                platform: platform,
                path: path,
                enabled: enabled,
                bookmark: bookmark,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String platform,
                required String path,
                Value<int> enabled = const Value.absent(),
                Value<String?> bookmark = const Value.absent(),
              }) => ScanFoldersCompanion.insert(
                id: id,
                platform: platform,
                path: path,
                enabled: enabled,
                bookmark: bookmark,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalMusicDatabase,
      $ScanFoldersTable,
      ScanFolder,
      $$ScanFoldersTableFilterComposer,
      $$ScanFoldersTableOrderingComposer,
      $$ScanFoldersTableAnnotationComposer,
      $$ScanFoldersTableCreateCompanionBuilder,
      $$ScanFoldersTableUpdateCompanionBuilder,
      (
        ScanFolder,
        BaseReferences<_$LocalMusicDatabase, $ScanFoldersTable, ScanFolder>,
      ),
      ScanFolder,
      PrefetchHooks Function()
    >;
typedef $$ArtistsTableCreateCompanionBuilder =
    ArtistsCompanion Function({Value<int> id, required String name});
typedef $$ArtistsTableUpdateCompanionBuilder =
    ArtistsCompanion Function({Value<int> id, Value<String> name});

final class $$ArtistsTableReferences
    extends BaseReferences<_$LocalMusicDatabase, $ArtistsTable, Artist> {
  $$ArtistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SongArtistsTable, List<SongArtist>>
  _songArtistsRefsTable(_$LocalMusicDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.songArtists,
        aliasName: 'artists__id__song_artists__artist_id',
      );

  $$SongArtistsTableProcessedTableManager get songArtistsRefs {
    final manager = $$SongArtistsTableTableManager(
      $_db,
      $_db.songArtists,
    ).filter((f) => f.artistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_songArtistsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ArtistsTableFilterComposer
    extends Composer<_$LocalMusicDatabase, $ArtistsTable> {
  $$ArtistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> songArtistsRefs(
    Expression<bool> Function($$SongArtistsTableFilterComposer f) f,
  ) {
    final $$SongArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songArtists,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongArtistsTableFilterComposer(
            $db: $db,
            $table: $db.songArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArtistsTableOrderingComposer
    extends Composer<_$LocalMusicDatabase, $ArtistsTable> {
  $$ArtistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArtistsTableAnnotationComposer
    extends Composer<_$LocalMusicDatabase, $ArtistsTable> {
  $$ArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> songArtistsRefs<T extends Object>(
    Expression<T> Function($$SongArtistsTableAnnotationComposer a) f,
  ) {
    final $$SongArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songArtists,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.songArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArtistsTableTableManager
    extends
        RootTableManager<
          _$LocalMusicDatabase,
          $ArtistsTable,
          Artist,
          $$ArtistsTableFilterComposer,
          $$ArtistsTableOrderingComposer,
          $$ArtistsTableAnnotationComposer,
          $$ArtistsTableCreateCompanionBuilder,
          $$ArtistsTableUpdateCompanionBuilder,
          (Artist, $$ArtistsTableReferences),
          Artist,
          PrefetchHooks Function({bool songArtistsRefs})
        > {
  $$ArtistsTableTableManager(_$LocalMusicDatabase db, $ArtistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => ArtistsCompanion(id: id, name: name),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String name}) =>
                  ArtistsCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ArtistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songArtistsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (songArtistsRefs) db.songArtists],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (songArtistsRefs)
                    await $_getPrefetchedData<
                      Artist,
                      $ArtistsTable,
                      SongArtist
                    >(
                      currentTable: table,
                      referencedTable: $$ArtistsTableReferences
                          ._songArtistsRefsTable(db),
                      managerFromTypedResult: (p0) => $$ArtistsTableReferences(
                        db,
                        table,
                        p0,
                      ).songArtistsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.artistId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalMusicDatabase,
      $ArtistsTable,
      Artist,
      $$ArtistsTableFilterComposer,
      $$ArtistsTableOrderingComposer,
      $$ArtistsTableAnnotationComposer,
      $$ArtistsTableCreateCompanionBuilder,
      $$ArtistsTableUpdateCompanionBuilder,
      (Artist, $$ArtistsTableReferences),
      Artist,
      PrefetchHooks Function({bool songArtistsRefs})
    >;
typedef $$SongArtistsTableCreateCompanionBuilder =
    SongArtistsCompanion Function({
      Value<int> id,
      required String songId,
      required int artistId,
    });
typedef $$SongArtistsTableUpdateCompanionBuilder =
    SongArtistsCompanion Function({
      Value<int> id,
      Value<String> songId,
      Value<int> artistId,
    });

final class $$SongArtistsTableReferences
    extends
        BaseReferences<_$LocalMusicDatabase, $SongArtistsTable, SongArtist> {
  $$SongArtistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LocalSongsTable _songIdTable(_$LocalMusicDatabase db) =>
      db.localSongs.createAlias('song_artists__song_id__local_songs__id');

  $$LocalSongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<String>('song_id')!;

    final manager = $$LocalSongsTableTableManager(
      $_db,
      $_db.localSongs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ArtistsTable _artistIdTable(_$LocalMusicDatabase db) =>
      db.artists.createAlias('song_artists__artist_id__artists__id');

  $$ArtistsTableProcessedTableManager get artistId {
    final $_column = $_itemColumn<int>('artist_id')!;

    final manager = $$ArtistsTableTableManager(
      $_db,
      $_db.artists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_artistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SongArtistsTableFilterComposer
    extends Composer<_$LocalMusicDatabase, $SongArtistsTable> {
  $$SongArtistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalSongsTableFilterComposer get songId {
    final $$LocalSongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.localSongs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSongsTableFilterComposer(
            $db: $db,
            $table: $db.localSongs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArtistsTableFilterComposer get artistId {
    final $$ArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableFilterComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SongArtistsTableOrderingComposer
    extends Composer<_$LocalMusicDatabase, $SongArtistsTable> {
  $$SongArtistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalSongsTableOrderingComposer get songId {
    final $$LocalSongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.localSongs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSongsTableOrderingComposer(
            $db: $db,
            $table: $db.localSongs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArtistsTableOrderingComposer get artistId {
    final $$ArtistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableOrderingComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SongArtistsTableAnnotationComposer
    extends Composer<_$LocalMusicDatabase, $SongArtistsTable> {
  $$SongArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  $$LocalSongsTableAnnotationComposer get songId {
    final $$LocalSongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.localSongs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSongsTableAnnotationComposer(
            $db: $db,
            $table: $db.localSongs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArtistsTableAnnotationComposer get artistId {
    final $$ArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.artists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.artists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SongArtistsTableTableManager
    extends
        RootTableManager<
          _$LocalMusicDatabase,
          $SongArtistsTable,
          SongArtist,
          $$SongArtistsTableFilterComposer,
          $$SongArtistsTableOrderingComposer,
          $$SongArtistsTableAnnotationComposer,
          $$SongArtistsTableCreateCompanionBuilder,
          $$SongArtistsTableUpdateCompanionBuilder,
          (SongArtist, $$SongArtistsTableReferences),
          SongArtist,
          PrefetchHooks Function({bool songId, bool artistId})
        > {
  $$SongArtistsTableTableManager(
    _$LocalMusicDatabase db,
    $SongArtistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongArtistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<int> artistId = const Value.absent(),
              }) => SongArtistsCompanion(
                id: id,
                songId: songId,
                artistId: artistId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String songId,
                required int artistId,
              }) => SongArtistsCompanion.insert(
                id: id,
                songId: songId,
                artistId: artistId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SongArtistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false, artistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.songId,
                                referencedTable: $$SongArtistsTableReferences
                                    ._songIdTable(db),
                                referencedColumn: $$SongArtistsTableReferences
                                    ._songIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (artistId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.artistId,
                                referencedTable: $$SongArtistsTableReferences
                                    ._artistIdTable(db),
                                referencedColumn: $$SongArtistsTableReferences
                                    ._artistIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SongArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalMusicDatabase,
      $SongArtistsTable,
      SongArtist,
      $$SongArtistsTableFilterComposer,
      $$SongArtistsTableOrderingComposer,
      $$SongArtistsTableAnnotationComposer,
      $$SongArtistsTableCreateCompanionBuilder,
      $$SongArtistsTableUpdateCompanionBuilder,
      (SongArtist, $$SongArtistsTableReferences),
      SongArtist,
      PrefetchHooks Function({bool songId, bool artistId})
    >;
typedef $$PlaybackQueuesTableCreateCompanionBuilder =
    PlaybackQueuesCompanion Function({
      required String slot,
      required String metadata,
      Value<int> rowid,
    });
typedef $$PlaybackQueuesTableUpdateCompanionBuilder =
    PlaybackQueuesCompanion Function({
      Value<String> slot,
      Value<String> metadata,
      Value<int> rowid,
    });

final class $$PlaybackQueuesTableReferences
    extends
        BaseReferences<
          _$LocalMusicDatabase,
          $PlaybackQueuesTable,
          PlaybackQueue
        > {
  $$PlaybackQueuesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $PlaybackQueueEntriesTable,
    List<PlaybackQueueEntry>
  >
  _playbackQueueEntriesRefsTable(_$LocalMusicDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.playbackQueueEntries,
        aliasName: 'playback_queues__slot__playback_queue_entries__slot',
      );

  $$PlaybackQueueEntriesTableProcessedTableManager
  get playbackQueueEntriesRefs {
    final manager = $$PlaybackQueueEntriesTableTableManager(
      $_db,
      $_db.playbackQueueEntries,
    ).filter((f) => f.slot.slot.sqlEquals($_itemColumn<String>('slot')!));

    final cache = $_typedResult.readTableOrNull(
      _playbackQueueEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaybackQueuesTableFilterComposer
    extends Composer<_$LocalMusicDatabase, $PlaybackQueuesTable> {
  $$PlaybackQueuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playbackQueueEntriesRefs(
    Expression<bool> Function($$PlaybackQueueEntriesTableFilterComposer f) f,
  ) {
    final $$PlaybackQueueEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slot,
      referencedTable: $db.playbackQueueEntries,
      getReferencedColumn: (t) => t.slot,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackQueueEntriesTableFilterComposer(
            $db: $db,
            $table: $db.playbackQueueEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaybackQueuesTableOrderingComposer
    extends Composer<_$LocalMusicDatabase, $PlaybackQueuesTable> {
  $$PlaybackQueuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackQueuesTableAnnotationComposer
    extends Composer<_$LocalMusicDatabase, $PlaybackQueuesTable> {
  $$PlaybackQueuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  Expression<T> playbackQueueEntriesRefs<T extends Object>(
    Expression<T> Function($$PlaybackQueueEntriesTableAnnotationComposer a) f,
  ) {
    final $$PlaybackQueueEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.slot,
          referencedTable: $db.playbackQueueEntries,
          getReferencedColumn: (t) => t.slot,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlaybackQueueEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.playbackQueueEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PlaybackQueuesTableTableManager
    extends
        RootTableManager<
          _$LocalMusicDatabase,
          $PlaybackQueuesTable,
          PlaybackQueue,
          $$PlaybackQueuesTableFilterComposer,
          $$PlaybackQueuesTableOrderingComposer,
          $$PlaybackQueuesTableAnnotationComposer,
          $$PlaybackQueuesTableCreateCompanionBuilder,
          $$PlaybackQueuesTableUpdateCompanionBuilder,
          (PlaybackQueue, $$PlaybackQueuesTableReferences),
          PlaybackQueue,
          PrefetchHooks Function({bool playbackQueueEntriesRefs})
        > {
  $$PlaybackQueuesTableTableManager(
    _$LocalMusicDatabase db,
    $PlaybackQueuesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackQueuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackQueuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackQueuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> slot = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackQueuesCompanion(
                slot: slot,
                metadata: metadata,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String slot,
                required String metadata,
                Value<int> rowid = const Value.absent(),
              }) => PlaybackQueuesCompanion.insert(
                slot: slot,
                metadata: metadata,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaybackQueuesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playbackQueueEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playbackQueueEntriesRefs) db.playbackQueueEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playbackQueueEntriesRefs)
                    await $_getPrefetchedData<
                      PlaybackQueue,
                      $PlaybackQueuesTable,
                      PlaybackQueueEntry
                    >(
                      currentTable: table,
                      referencedTable: $$PlaybackQueuesTableReferences
                          ._playbackQueueEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlaybackQueuesTableReferences(
                            db,
                            table,
                            p0,
                          ).playbackQueueEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.slot == item.slot),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlaybackQueuesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalMusicDatabase,
      $PlaybackQueuesTable,
      PlaybackQueue,
      $$PlaybackQueuesTableFilterComposer,
      $$PlaybackQueuesTableOrderingComposer,
      $$PlaybackQueuesTableAnnotationComposer,
      $$PlaybackQueuesTableCreateCompanionBuilder,
      $$PlaybackQueuesTableUpdateCompanionBuilder,
      (PlaybackQueue, $$PlaybackQueuesTableReferences),
      PlaybackQueue,
      PrefetchHooks Function({bool playbackQueueEntriesRefs})
    >;
typedef $$PlaybackQueueEntriesTableCreateCompanionBuilder =
    PlaybackQueueEntriesCompanion Function({
      required String slot,
      required int position,
      required String payload,
      Value<int> rowid,
    });
typedef $$PlaybackQueueEntriesTableUpdateCompanionBuilder =
    PlaybackQueueEntriesCompanion Function({
      Value<String> slot,
      Value<int> position,
      Value<String> payload,
      Value<int> rowid,
    });

final class $$PlaybackQueueEntriesTableReferences
    extends
        BaseReferences<
          _$LocalMusicDatabase,
          $PlaybackQueueEntriesTable,
          PlaybackQueueEntry
        > {
  $$PlaybackQueueEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaybackQueuesTable _slotTable(_$LocalMusicDatabase db) => db
      .playbackQueues
      .createAlias('playback_queue_entries__slot__playback_queues__slot');

  $$PlaybackQueuesTableProcessedTableManager get slot {
    final $_column = $_itemColumn<String>('slot')!;

    final manager = $$PlaybackQueuesTableTableManager(
      $_db,
      $_db.playbackQueues,
    ).filter((f) => f.slot.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_slotTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaybackQueueEntriesTableFilterComposer
    extends Composer<_$LocalMusicDatabase, $PlaybackQueueEntriesTable> {
  $$PlaybackQueueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaybackQueuesTableFilterComposer get slot {
    final $$PlaybackQueuesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slot,
      referencedTable: $db.playbackQueues,
      getReferencedColumn: (t) => t.slot,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackQueuesTableFilterComposer(
            $db: $db,
            $table: $db.playbackQueues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackQueueEntriesTableOrderingComposer
    extends Composer<_$LocalMusicDatabase, $PlaybackQueueEntriesTable> {
  $$PlaybackQueueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaybackQueuesTableOrderingComposer get slot {
    final $$PlaybackQueuesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slot,
      referencedTable: $db.playbackQueues,
      getReferencedColumn: (t) => t.slot,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackQueuesTableOrderingComposer(
            $db: $db,
            $table: $db.playbackQueues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackQueueEntriesTableAnnotationComposer
    extends Composer<_$LocalMusicDatabase, $PlaybackQueueEntriesTable> {
  $$PlaybackQueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  $$PlaybackQueuesTableAnnotationComposer get slot {
    final $$PlaybackQueuesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slot,
      referencedTable: $db.playbackQueues,
      getReferencedColumn: (t) => t.slot,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackQueuesTableAnnotationComposer(
            $db: $db,
            $table: $db.playbackQueues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackQueueEntriesTableTableManager
    extends
        RootTableManager<
          _$LocalMusicDatabase,
          $PlaybackQueueEntriesTable,
          PlaybackQueueEntry,
          $$PlaybackQueueEntriesTableFilterComposer,
          $$PlaybackQueueEntriesTableOrderingComposer,
          $$PlaybackQueueEntriesTableAnnotationComposer,
          $$PlaybackQueueEntriesTableCreateCompanionBuilder,
          $$PlaybackQueueEntriesTableUpdateCompanionBuilder,
          (PlaybackQueueEntry, $$PlaybackQueueEntriesTableReferences),
          PlaybackQueueEntry,
          PrefetchHooks Function({bool slot})
        > {
  $$PlaybackQueueEntriesTableTableManager(
    _$LocalMusicDatabase db,
    $PlaybackQueueEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackQueueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackQueueEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PlaybackQueueEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> slot = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackQueueEntriesCompanion(
                slot: slot,
                position: position,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String slot,
                required int position,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => PlaybackQueueEntriesCompanion.insert(
                slot: slot,
                position: position,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaybackQueueEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({slot = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (slot) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.slot,
                                referencedTable:
                                    $$PlaybackQueueEntriesTableReferences
                                        ._slotTable(db),
                                referencedColumn:
                                    $$PlaybackQueueEntriesTableReferences
                                        ._slotTable(db)
                                        .slot,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaybackQueueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalMusicDatabase,
      $PlaybackQueueEntriesTable,
      PlaybackQueueEntry,
      $$PlaybackQueueEntriesTableFilterComposer,
      $$PlaybackQueueEntriesTableOrderingComposer,
      $$PlaybackQueueEntriesTableAnnotationComposer,
      $$PlaybackQueueEntriesTableCreateCompanionBuilder,
      $$PlaybackQueueEntriesTableUpdateCompanionBuilder,
      (PlaybackQueueEntry, $$PlaybackQueueEntriesTableReferences),
      PlaybackQueueEntry,
      PrefetchHooks Function({bool slot})
    >;
typedef $$PlaybackHistoryTableCreateCompanionBuilder =
    PlaybackHistoryCompanion Function({
      required String trackKey,
      required int playedAt,
      required String payload,
      Value<int> rowid,
    });
typedef $$PlaybackHistoryTableUpdateCompanionBuilder =
    PlaybackHistoryCompanion Function({
      Value<String> trackKey,
      Value<int> playedAt,
      Value<String> payload,
      Value<int> rowid,
    });

class $$PlaybackHistoryTableFilterComposer
    extends Composer<_$LocalMusicDatabase, $PlaybackHistoryTable> {
  $$PlaybackHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackKey => $composableBuilder(
    column: $table.trackKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackHistoryTableOrderingComposer
    extends Composer<_$LocalMusicDatabase, $PlaybackHistoryTable> {
  $$PlaybackHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackKey => $composableBuilder(
    column: $table.trackKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackHistoryTableAnnotationComposer
    extends Composer<_$LocalMusicDatabase, $PlaybackHistoryTable> {
  $$PlaybackHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackKey =>
      $composableBuilder(column: $table.trackKey, builder: (column) => column);

  GeneratedColumn<int> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$PlaybackHistoryTableTableManager
    extends
        RootTableManager<
          _$LocalMusicDatabase,
          $PlaybackHistoryTable,
          PlaybackHistoryData,
          $$PlaybackHistoryTableFilterComposer,
          $$PlaybackHistoryTableOrderingComposer,
          $$PlaybackHistoryTableAnnotationComposer,
          $$PlaybackHistoryTableCreateCompanionBuilder,
          $$PlaybackHistoryTableUpdateCompanionBuilder,
          (
            PlaybackHistoryData,
            BaseReferences<
              _$LocalMusicDatabase,
              $PlaybackHistoryTable,
              PlaybackHistoryData
            >,
          ),
          PlaybackHistoryData,
          PrefetchHooks Function()
        > {
  $$PlaybackHistoryTableTableManager(
    _$LocalMusicDatabase db,
    $PlaybackHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> trackKey = const Value.absent(),
                Value<int> playedAt = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackHistoryCompanion(
                trackKey: trackKey,
                playedAt: playedAt,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trackKey,
                required int playedAt,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => PlaybackHistoryCompanion.insert(
                trackKey: trackKey,
                playedAt: playedAt,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalMusicDatabase,
      $PlaybackHistoryTable,
      PlaybackHistoryData,
      $$PlaybackHistoryTableFilterComposer,
      $$PlaybackHistoryTableOrderingComposer,
      $$PlaybackHistoryTableAnnotationComposer,
      $$PlaybackHistoryTableCreateCompanionBuilder,
      $$PlaybackHistoryTableUpdateCompanionBuilder,
      (
        PlaybackHistoryData,
        BaseReferences<
          _$LocalMusicDatabase,
          $PlaybackHistoryTable,
          PlaybackHistoryData
        >,
      ),
      PlaybackHistoryData,
      PrefetchHooks Function()
    >;
typedef $$StoredDownloadTasksTableCreateCompanionBuilder =
    StoredDownloadTasksCompanion Function({
      required String taskId,
      required int updatedAt,
      required String payload,
      Value<int> rowid,
    });
typedef $$StoredDownloadTasksTableUpdateCompanionBuilder =
    StoredDownloadTasksCompanion Function({
      Value<String> taskId,
      Value<int> updatedAt,
      Value<String> payload,
      Value<int> rowid,
    });

class $$StoredDownloadTasksTableFilterComposer
    extends Composer<_$LocalMusicDatabase, $StoredDownloadTasksTable> {
  $$StoredDownloadTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredDownloadTasksTableOrderingComposer
    extends Composer<_$LocalMusicDatabase, $StoredDownloadTasksTable> {
  $$StoredDownloadTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredDownloadTasksTableAnnotationComposer
    extends Composer<_$LocalMusicDatabase, $StoredDownloadTasksTable> {
  $$StoredDownloadTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$StoredDownloadTasksTableTableManager
    extends
        RootTableManager<
          _$LocalMusicDatabase,
          $StoredDownloadTasksTable,
          StoredDownloadTask,
          $$StoredDownloadTasksTableFilterComposer,
          $$StoredDownloadTasksTableOrderingComposer,
          $$StoredDownloadTasksTableAnnotationComposer,
          $$StoredDownloadTasksTableCreateCompanionBuilder,
          $$StoredDownloadTasksTableUpdateCompanionBuilder,
          (
            StoredDownloadTask,
            BaseReferences<
              _$LocalMusicDatabase,
              $StoredDownloadTasksTable,
              StoredDownloadTask
            >,
          ),
          StoredDownloadTask,
          PrefetchHooks Function()
        > {
  $$StoredDownloadTasksTableTableManager(
    _$LocalMusicDatabase db,
    $StoredDownloadTasksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredDownloadTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoredDownloadTasksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$StoredDownloadTasksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> taskId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredDownloadTasksCompanion(
                taskId: taskId,
                updatedAt: updatedAt,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String taskId,
                required int updatedAt,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => StoredDownloadTasksCompanion.insert(
                taskId: taskId,
                updatedAt: updatedAt,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoredDownloadTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalMusicDatabase,
      $StoredDownloadTasksTable,
      StoredDownloadTask,
      $$StoredDownloadTasksTableFilterComposer,
      $$StoredDownloadTasksTableOrderingComposer,
      $$StoredDownloadTasksTableAnnotationComposer,
      $$StoredDownloadTasksTableCreateCompanionBuilder,
      $$StoredDownloadTasksTableUpdateCompanionBuilder,
      (
        StoredDownloadTask,
        BaseReferences<
          _$LocalMusicDatabase,
          $StoredDownloadTasksTable,
          StoredDownloadTask
        >,
      ),
      StoredDownloadTask,
      PrefetchHooks Function()
    >;
typedef $$CachedFavoriteSongsTableCreateCompanionBuilder =
    CachedFavoriteSongsCompanion Function({
      required String platform,
      required String songId,
      Value<int> rowid,
    });
typedef $$CachedFavoriteSongsTableUpdateCompanionBuilder =
    CachedFavoriteSongsCompanion Function({
      Value<String> platform,
      Value<String> songId,
      Value<int> rowid,
    });

class $$CachedFavoriteSongsTableFilterComposer
    extends Composer<_$LocalMusicDatabase, $CachedFavoriteSongsTable> {
  $$CachedFavoriteSongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get songId => $composableBuilder(
    column: $table.songId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedFavoriteSongsTableOrderingComposer
    extends Composer<_$LocalMusicDatabase, $CachedFavoriteSongsTable> {
  $$CachedFavoriteSongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get songId => $composableBuilder(
    column: $table.songId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedFavoriteSongsTableAnnotationComposer
    extends Composer<_$LocalMusicDatabase, $CachedFavoriteSongsTable> {
  $$CachedFavoriteSongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);
}

class $$CachedFavoriteSongsTableTableManager
    extends
        RootTableManager<
          _$LocalMusicDatabase,
          $CachedFavoriteSongsTable,
          CachedFavoriteSong,
          $$CachedFavoriteSongsTableFilterComposer,
          $$CachedFavoriteSongsTableOrderingComposer,
          $$CachedFavoriteSongsTableAnnotationComposer,
          $$CachedFavoriteSongsTableCreateCompanionBuilder,
          $$CachedFavoriteSongsTableUpdateCompanionBuilder,
          (
            CachedFavoriteSong,
            BaseReferences<
              _$LocalMusicDatabase,
              $CachedFavoriteSongsTable,
              CachedFavoriteSong
            >,
          ),
          CachedFavoriteSong,
          PrefetchHooks Function()
        > {
  $$CachedFavoriteSongsTableTableManager(
    _$LocalMusicDatabase db,
    $CachedFavoriteSongsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedFavoriteSongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedFavoriteSongsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedFavoriteSongsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> platform = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedFavoriteSongsCompanion(
                platform: platform,
                songId: songId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String platform,
                required String songId,
                Value<int> rowid = const Value.absent(),
              }) => CachedFavoriteSongsCompanion.insert(
                platform: platform,
                songId: songId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedFavoriteSongsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalMusicDatabase,
      $CachedFavoriteSongsTable,
      CachedFavoriteSong,
      $$CachedFavoriteSongsTableFilterComposer,
      $$CachedFavoriteSongsTableOrderingComposer,
      $$CachedFavoriteSongsTableAnnotationComposer,
      $$CachedFavoriteSongsTableCreateCompanionBuilder,
      $$CachedFavoriteSongsTableUpdateCompanionBuilder,
      (
        CachedFavoriteSong,
        BaseReferences<
          _$LocalMusicDatabase,
          $CachedFavoriteSongsTable,
          CachedFavoriteSong
        >,
      ),
      CachedFavoriteSong,
      PrefetchHooks Function()
    >;
typedef $$StorageMigrationsTableCreateCompanionBuilder =
    StorageMigrationsCompanion Function({
      required String storageKey,
      Value<int> rowid,
    });
typedef $$StorageMigrationsTableUpdateCompanionBuilder =
    StorageMigrationsCompanion Function({
      Value<String> storageKey,
      Value<int> rowid,
    });

class $$StorageMigrationsTableFilterComposer
    extends Composer<_$LocalMusicDatabase, $StorageMigrationsTable> {
  $$StorageMigrationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StorageMigrationsTableOrderingComposer
    extends Composer<_$LocalMusicDatabase, $StorageMigrationsTable> {
  $$StorageMigrationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StorageMigrationsTableAnnotationComposer
    extends Composer<_$LocalMusicDatabase, $StorageMigrationsTable> {
  $$StorageMigrationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => column,
  );
}

class $$StorageMigrationsTableTableManager
    extends
        RootTableManager<
          _$LocalMusicDatabase,
          $StorageMigrationsTable,
          StorageMigration,
          $$StorageMigrationsTableFilterComposer,
          $$StorageMigrationsTableOrderingComposer,
          $$StorageMigrationsTableAnnotationComposer,
          $$StorageMigrationsTableCreateCompanionBuilder,
          $$StorageMigrationsTableUpdateCompanionBuilder,
          (
            StorageMigration,
            BaseReferences<
              _$LocalMusicDatabase,
              $StorageMigrationsTable,
              StorageMigration
            >,
          ),
          StorageMigration,
          PrefetchHooks Function()
        > {
  $$StorageMigrationsTableTableManager(
    _$LocalMusicDatabase db,
    $StorageMigrationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StorageMigrationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StorageMigrationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StorageMigrationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> storageKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StorageMigrationsCompanion(
                storageKey: storageKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String storageKey,
                Value<int> rowid = const Value.absent(),
              }) => StorageMigrationsCompanion.insert(
                storageKey: storageKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StorageMigrationsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalMusicDatabase,
      $StorageMigrationsTable,
      StorageMigration,
      $$StorageMigrationsTableFilterComposer,
      $$StorageMigrationsTableOrderingComposer,
      $$StorageMigrationsTableAnnotationComposer,
      $$StorageMigrationsTableCreateCompanionBuilder,
      $$StorageMigrationsTableUpdateCompanionBuilder,
      (
        StorageMigration,
        BaseReferences<
          _$LocalMusicDatabase,
          $StorageMigrationsTable,
          StorageMigration
        >,
      ),
      StorageMigration,
      PrefetchHooks Function()
    >;

class $LocalMusicDatabaseManager {
  final _$LocalMusicDatabase _db;
  $LocalMusicDatabaseManager(this._db);
  $$LocalSongsTableTableManager get localSongs =>
      $$LocalSongsTableTableManager(_db, _db.localSongs);
  $$PlayStatsTableTableManager get playStats =>
      $$PlayStatsTableTableManager(_db, _db.playStats);
  $$ScanFoldersTableTableManager get scanFolders =>
      $$ScanFoldersTableTableManager(_db, _db.scanFolders);
  $$ArtistsTableTableManager get artists =>
      $$ArtistsTableTableManager(_db, _db.artists);
  $$SongArtistsTableTableManager get songArtists =>
      $$SongArtistsTableTableManager(_db, _db.songArtists);
  $$PlaybackQueuesTableTableManager get playbackQueues =>
      $$PlaybackQueuesTableTableManager(_db, _db.playbackQueues);
  $$PlaybackQueueEntriesTableTableManager get playbackQueueEntries =>
      $$PlaybackQueueEntriesTableTableManager(_db, _db.playbackQueueEntries);
  $$PlaybackHistoryTableTableManager get playbackHistory =>
      $$PlaybackHistoryTableTableManager(_db, _db.playbackHistory);
  $$StoredDownloadTasksTableTableManager get storedDownloadTasks =>
      $$StoredDownloadTasksTableTableManager(_db, _db.storedDownloadTasks);
  $$CachedFavoriteSongsTableTableManager get cachedFavoriteSongs =>
      $$CachedFavoriteSongsTableTableManager(_db, _db.cachedFavoriteSongs);
  $$StorageMigrationsTableTableManager get storageMigrations =>
      $$StorageMigrationsTableTableManager(_db, _db.storageMigrations);
}
