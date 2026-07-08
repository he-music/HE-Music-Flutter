use super::{error::AudioTagsError, tag::Tag};
use lofty::{
    Accessor, AudioFile, ItemKey, ItemValue, Probe, TagExt, TagItem, TagType, TaggedFile,
    TaggedFileExt,
};

/// Returns a `TaggedFile` at the given path.
fn get_file(path: &str) -> Result<TaggedFile, AudioTagsError> {
    match Probe::open(path) {
        Ok(file) => match file.read() {
            Ok(file) => Ok(file),
            Err(err) => Err(AudioTagsError::OpenFile {
                message: err.to_string(),
            }),
        },
        Err(_) => Err(AudioTagsError::InvalidPath),
    }
}

pub fn read(path: String) -> Result<Tag, AudioTagsError> {
    let file = get_file(&path)?;

    let tag = match file.primary_tag() {
        Some(primary_tag) => Ok(primary_tag),
        None => match file.first_tag() {
            Some(first_tag) => Ok(first_tag),
            None => Err(AudioTagsError::NoTags),
        },
    }?;

    let mut tag = Tag::from(tag);
    let properties = file.properties();
    tag.duration = Some(properties.duration().as_secs() as u32);
    tag.bitrate = properties.audio_bitrate().or_else(|| properties.overall_bitrate());
    tag.sample_rate = properties.sample_rate();

    Ok(tag)
}

pub fn write(path: String, data: Tag) -> Result<(), AudioTagsError> {
    let mut file = get_file(&path)?;

    // Remove the existing tags.
    for tag in file.tags() {
        if let Err(err) = tag.remove_from_path(&path) {
            return Err(AudioTagsError::Write {
                message: format!("Could not remove existing tag. {err:?}"),
            });
        }
    }

    // If there is no data to be written, then return.
    if data.is_empty() {
        return Ok(());
    }

    // Create a new tag.
    file.insert_tag(lofty::Tag::new(file.primary_tag_type()));
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
            lofty::Picture::new_unchecked(
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

    match tag.save_to_path(path) {
        Ok(_) => Ok(()),
        Err(err) => Err(AudioTagsError::Write {
            message: format!("Failed to write tag to file. {err:?}"),
        }),
    }
}

fn insert_text_values(tag: &mut lofty::Tag, tag_type: TagType, key: ItemKey, values: &[String]) {
    let values = values
        .iter()
        .map(|item| item.trim())
        .filter(|item| !item.is_empty())
        .collect::<Vec<&str>>();

    if tag_type == TagType::VorbisComments {
        match values.as_slice() {
            [] => {},
            [single] => {
                tag.insert_text(key, (*single).to_owned());
            },
            _ => {
                for item in values {
                    let _ = tag.push(TagItem::new(key.clone(), ItemValue::Text(item.to_owned())));
                }
            },
        }
        return;
    }

    match values.as_slice() {
        [] => {},
        [single] => {
            tag.insert_text(key, (*single).to_owned());
        },
        _ if tag_type == TagType::Id3v2 => {
            tag.insert_text(key, values.join("\0"));
        },
        _ => {
            for item in values {
                let _ = tag.push(TagItem::new(key.clone(), ItemValue::Text(item.to_owned())));
            }
        },
    }
}

#[cfg(test)]
mod tests {
    use super::insert_text_values;
    use lofty::{ItemKey, Tag, TagType};

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
