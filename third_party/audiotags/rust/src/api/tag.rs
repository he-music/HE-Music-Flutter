use lofty::prelude::{Accessor, ItemKey};

use super::picture::Picture;

/// Represents the metadata of the file.
#[derive(Default)]
pub struct Tag {
    /// The title of the song.
    pub title: Option<String>,
    /// The artists of the song.
    pub artists: Vec<String>,
    /// The album the song is from.
    pub album: Option<String>,
    /// The artists of the album.
    pub album_artists: Vec<String>,
    /// The year that this song was made.
    pub year: Option<u32>,
    /// The genre of the song.
    pub genre: Option<String>,
    /// The position of the song in a list.
    pub track_number: Option<u32>,
    /// The total amount of songs in a list.
    pub track_total: Option<u32>,
    /// The position of the disc in a list.
    pub disc_number: Option<u32>,
    /// The total amount of discs in a list.
    pub disc_total: Option<u32>,
    /// The lyrics of the song.
    pub lyrics: Option<String>,
    /// The duration of the song. Setting this field
    /// when writing will do nothing.
    pub duration: Option<u32>,
    /// The audio bitrate in kbps. Setting this field
    /// when writing will do nothing.
    pub bitrate: Option<u32>,
    /// The sample rate in Hz. Setting this field
    /// when writing will do nothing.
    pub sample_rate: Option<u32>,
    /// All the pictures of the song.
    pub pictures: Vec<Picture>,
    /// Beats per minute.
    pub bpm: Option<f32>,
}

impl Tag {
    /// Returns `true` if the tag has no data.
    pub fn is_empty(&self) -> bool {
        self.title.is_none()
            && self.artists.is_empty()
            && self.album.is_none()
            && self.album_artists.is_empty()
            && self.year.is_none()
            && self.genre.is_none()
            && self.track_number.is_none()
            && self.track_total.is_none()
            && self.disc_number.is_none()
            && self.disc_total.is_none()
            && self.duration.is_none()
            && self.pictures.is_empty()
            && self.lyrics.is_none()
            && self.bpm.is_none()
    }
}

impl From<&lofty::tag::Tag> for Tag {
    fn from(tag: &lofty::tag::Tag) -> Self {
        Self::from_selected(tag, true, true, true)
    }
}

impl Tag {
    pub(crate) fn from_selected(
        tag: &lofty::tag::Tag,
        tags: bool,
        lyrics: bool,
        pictures: bool,
    ) -> Self {
        let mut result = Self::default();
        if tags {
            result.title = tag.title().map(|value| value.to_string());
            result.artists = collect_text_values(tag, &ItemKey::TrackArtist);
            result.album = tag.album().map(|value| value.to_string());
            result.album_artists = collect_text_values(tag, &ItemKey::AlbumArtist);
            result.year = tag.year();
            result.genre = tag.genre().map(|value| value.to_string());
            result.track_number = tag.track();
            result.track_total = tag.track_total();
            result.disc_number = tag.disk();
            result.disc_total = tag.disk_total();
            result.bpm = tag
                .get_string(&ItemKey::Bpm)
                .or_else(|| tag.get_string(&ItemKey::IntegerBpm))
                .and_then(|value| value.parse().ok());
        }
        if lyrics {
            result.lyrics = tag.get_string(&ItemKey::Lyrics).map(str::to_owned);
        }
        if pictures {
            result.pictures = tag
                .pictures()
                .iter()
                .map(|picture| {
                    Picture::new(
                        picture.pic_type().into(),
                        picture.mime_type().cloned().map(Into::into),
                        picture.data().to_vec(),
                    )
                })
                .collect();
        }
        result
    }
}

fn collect_text_values(tag: &lofty::tag::Tag, key: &ItemKey) -> Vec<String> {
    tag.get_strings(key)
        .flat_map(|value| value.split('\0'))
        .map(str::trim)
        .filter(|item| !item.is_empty())
        .map(str::to_owned)
        .collect::<Vec<String>>()
}

#[cfg(test)]
mod tests {
    use super::Tag as ApiTag;
    use lofty::{
        prelude::ItemKey,
        tag::{ItemValue, Tag, TagItem, TagType},
    };

    #[test]
    fn from_lofty_tag_joins_multi_artist_vorbis_values_with_null() {
        let mut tag = Tag::new(TagType::VorbisComments);
        tag.insert_text(ItemKey::TrackArtist, "Lady Gaga".to_owned());
        let _ = tag.push(TagItem::new(
            ItemKey::TrackArtist,
            ItemValue::Text("Doechii".to_owned()),
        ));

        let converted = ApiTag::from(&tag);

        assert_eq!(converted.artists, vec!["Lady Gaga", "Doechii"]);
    }
}
