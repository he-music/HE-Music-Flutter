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

abstract class _$LocalMusicDatabase extends GeneratedDatabase {
  _$LocalMusicDatabase(QueryExecutor e) : super(e);
  $LocalMusicDatabaseManager get managers => $LocalMusicDatabaseManager(this);
  late final $LocalSongsTable localSongs = $LocalSongsTable(this);
  late final $PlayStatsTable playStats = $PlayStatsTable(this);
  late final $ScanFoldersTable scanFolders = $ScanFoldersTable(this);
  late final $ArtistsTable artists = $ArtistsTable(this);
  late final $SongArtistsTable songArtists = $SongArtistsTable(this);
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
  ];
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
    aliasName: $_aliasNameGenerator(db.localSongs.id, db.playStats.songId),
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
        aliasName: $_aliasNameGenerator(
          db.localSongs.id,
          db.songArtists.songId,
        ),
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

  static $LocalSongsTable _songIdTable(_$LocalMusicDatabase db) => db.localSongs
      .createAlias($_aliasNameGenerator(db.playStats.songId, db.localSongs.id));

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
        aliasName: $_aliasNameGenerator(db.artists.id, db.songArtists.artistId),
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
      db.localSongs.createAlias(
        $_aliasNameGenerator(db.songArtists.songId, db.localSongs.id),
      );

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
      db.artists.createAlias(
        $_aliasNameGenerator(db.songArtists.artistId, db.artists.id),
      );

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
}
