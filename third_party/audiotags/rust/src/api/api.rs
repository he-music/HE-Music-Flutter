use super::{error::AudioTagsError, picture::Picture, tag::Tag};
use lofty::{
    config::{ParseOptions, WriteOptions},
    file::{AudioFile, TaggedFile, TaggedFileExt},
    prelude::{Accessor, ItemKey, TagExt},
    probe::Probe,
    tag::{ItemValue, TagItem, TagType},
};

fn get_file_with_options(path: &str, options: ParseOptions) -> Result<TaggedFile, AudioTagsError> {
    Probe::open(path)
        .map_err(|_| AudioTagsError::InvalidPath)?
        .options(options)
        .read()
        .map_err(|err| AudioTagsError::OpenFile {
            message: err.to_string(),
        })
}

fn get_file(path: &str) -> Result<TaggedFile, AudioTagsError> {
    get_file_with_options(path, ParseOptions::new())
}

/// Compatibility entry point: read all supported fields.
pub fn read(path: String) -> Result<Tag, AudioTagsError> {
    read_with_options(path, true, true, true, true)
}

/// Select field groups before parsing and before copying data across FFI.
/// Tag containers must still be traversed when reading text, lyrics, or pictures.
pub fn read_with_options(
    path: String,
    tags: bool,
    properties: bool,
    lyrics: bool,
    pictures: bool,
) -> Result<Tag, AudioTagsError> {
    let options = ParseOptions::new()
        .read_properties(properties)
        .read_tags(tags || lyrics || pictures)
        .read_cover_art(pictures);
    let file = get_file_with_options(&path, options)?;
    let source = file.primary_tag().or_else(|| file.first_tag());
    if source.is_none() && (tags || lyrics || pictures) {
        return Err(AudioTagsError::NoTags);
    }
    let mut tag = source
        .map(|tag| Tag::from_selected(tag, tags, lyrics, pictures))
        .unwrap_or_default();
    if properties {
        let properties = file.properties();
        tag.duration = Some(properties.duration().as_secs() as u32);
        tag.bitrate = properties
            .audio_bitrate()
            .or_else(|| properties.overall_bitrate());
        tag.sample_rate = properties.sample_rate();
    }
    Ok(tag)
}

/// Read one preferred cover without computing audio properties or returning text tags.
pub fn read_artwork(path: String) -> Result<Option<Picture>, AudioTagsError> {
    let file = get_file_with_options(
        &path,
        ParseOptions::new()
            .read_properties(false)
            .read_cover_art(true),
    )?;
    let pictures = file
        .primary_tag()
        .or_else(|| file.first_tag())
        .map(|tag| tag.pictures());
    Ok(pictures.and_then(|pictures| {
        pictures
            .iter()
            .find(|picture| {
                picture.pic_type() == lofty::picture::PictureType::CoverFront
                    && !picture.data().is_empty()
            })
            .or_else(|| pictures.iter().find(|picture| !picture.data().is_empty()))
            .map(|picture| {
                Picture::new(
                    picture.pic_type().into(),
                    picture.mime_type().cloned().map(Into::into),
                    picture.data().to_vec(),
                )
            })
    }))
}
pub fn write(path: String, data: Tag) -> Result<(), AudioTagsError> {
    let mut file = get_file(&path)?;

    // Replace the primary tag and let Lofty remove other tag containers in the
    // same write. Removing an MP4 tag before writing can leave an empty meta atom.
    file.insert_tag(lofty::tag::Tag::new(file.primary_tag_type()));
    let tag_type = file.primary_tag_type();
    let tag = file.primary_tag_mut().unwrap();

    // Title
    if let Some(title) = data.title {
        tag.insert_text(ItemKey::TrackTitle, title);
    }

    // Track Artist
    if !data.artists.is_empty() {
        insert_text_values(tag, tag_type, ItemKey::TrackArtist, &data.artists);
    }

    // Album Title
    if let Some(album) = data.album {
        tag.insert_text(ItemKey::AlbumTitle, album);
    }

    // Album Artist
    if !data.album_artists.is_empty() {
        insert_text_values(tag, tag_type, ItemKey::AlbumArtist, &data.album_artists);
    }

    // Year
    if let Some(year) = data.year {
        tag.set_year(year);
    }

    // Track number
    if let Some(track_number) = data.track_number {
        tag.set_track(track_number);
    }

    // Track total
    if let Some(track_total) = data.track_total {
        tag.set_track_total(track_total);
    }

    // Disc number
    if let Some(disc_number) = data.disc_number {
        tag.set_disk(disc_number);
    }

    // Disc total
    if let Some(disc_total) = data.disc_total {
        tag.set_disk_total(disc_total);
    }

    // Genre
    if let Some(genre) = data.genre {
        tag.insert_text(ItemKey::Genre, genre);
    }

    // Pictures
    for (i, picture) in data.pictures.into_iter().enumerate() {
        let mime_type = picture.mime_type.map(|p| p.into());

        tag.set_picture(
            i,
            lofty::picture::Picture::new_unchecked(
                picture.picture_type.into(),
                mime_type,
                None,
                picture.bytes,
            ),
        );
    }

    // Lyrics
    if let Some(lyrics) = data.lyrics {
        tag.insert_text(ItemKey::Lyrics, lyrics);
    }

    // Bpm
    if let Some(bpm) = data.bpm {
        if !tag.insert_text(ItemKey::Bpm, bpm.to_string()) {
            tag.insert_text(ItemKey::IntegerBpm, (bpm as u32).to_string());
        }
    }

    match tag.save_to_path(path, WriteOptions::default().remove_others(true)) {
        Ok(_) => Ok(()),
        Err(err) => Err(AudioTagsError::Write {
            message: format!("Failed to write tag to file. {err:?}"),
        }),
    }
}

fn insert_text_values(
    tag: &mut lofty::tag::Tag,
    tag_type: TagType,
    key: ItemKey,
    values: &[String],
) {
    let values = values
        .iter()
        .map(|item| item.trim())
        .filter(|item| !item.is_empty())
        .collect::<Vec<&str>>();

    if tag_type == TagType::VorbisComments {
        match values.as_slice() {
            [] => {}
            [single] => {
                tag.insert_text(key, (*single).to_owned());
            }
            _ => {
                for item in values {
                    let _ = tag.push(TagItem::new(key.clone(), ItemValue::Text(item.to_owned())));
                }
            }
        }
        return;
    }

    match values.as_slice() {
        [] => {}
        [single] => {
            tag.insert_text(key, (*single).to_owned());
        }
        _ if tag_type == TagType::Id3v2 => {
            tag.insert_text(key, values.join("\0"));
        }
        _ => {
            for item in values {
                let _ = tag.push(TagItem::new(key.clone(), ItemValue::Text(item.to_owned())));
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::insert_text_values;
    use lofty::{
        prelude::ItemKey,
        tag::{Tag, TagType},
    };

    #[test]
    fn insert_text_values_splits_null_separated_artists_for_vorbis_comments() {
        let mut tag = Tag::new(TagType::VorbisComments);

        insert_text_values(
            &mut tag,
            TagType::VorbisComments,
            ItemKey::TrackArtist,
            &vec!["Lady Gaga".to_owned(), "Doechii".to_owned()],
        );

        let values = tag
            .get_strings(&ItemKey::TrackArtist)
            .collect::<Vec<&str>>();
        assert_eq!(values, vec!["Lady Gaga", "Doechii"]);
    }
}
