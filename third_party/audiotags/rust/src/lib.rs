mod api;
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

#[cfg(test)]
mod tests {
    use crate::api::{
        api,
        picture::{MimeType, Picture, PictureType},
        tag::Tag,
    };
    use std::{
        fs,
        path::PathBuf,
        sync::atomic::{AtomicU64, Ordering},
    };

    static NEXT_FILE: AtomicU64 = AtomicU64::new(0);

    struct Fixture(PathBuf);
    impl Fixture {
        fn new(extension: &str, bytes: &[u8]) -> Self {
            let path = std::env::temp_dir().join(format!(
                "audiotags-{}-{}.{}",
                std::process::id(),
                NEXT_FILE.fetch_add(1, Ordering::Relaxed),
                extension,
            ));
            fs::write(&path, bytes).unwrap();
            Self(path)
        }
        fn path(&self) -> String {
            self.0.to_str().unwrap().to_owned()
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_file(&self.0);
        }
    }

    fn fixtures() -> Vec<Fixture> {
        vec![
            Fixture::new("mp3", include_bytes!("../../test/fixtures/silence.mp3")),
            Fixture::new("m4a", include_bytes!("../../test/fixtures/silence.m4a")),
            Fixture::new("flac", include_bytes!("../../test/fixtures/silence.flac")),
            Fixture::new("wav", include_bytes!("../../test/fixtures/silence.wav")),
        ]
    }

    fn tagged_fixture(fixture: &Fixture) {
        api::write(
            fixture.path(),
            Tag {
                title: Some("Title".into()),
                artists: vec!["Artist A".into(), "Artist B".into()],
                album: Some("Album".into()),
                lyrics: Some("Lyrics".into()),
                pictures: vec![
                    Picture::new(PictureType::CoverBack, Some(MimeType::Jpeg), vec![9, 8, 7]),
                    Picture::new(PictureType::CoverFront, Some(MimeType::Jpeg), vec![1, 2, 3]),
                ],
                ..Default::default()
            },
        )
        .unwrap();
    }

    #[test]
    fn selective_scan_retains_tags_and_properties_without_lyrics_or_pictures() {
        for fixture in fixtures() {
            tagged_fixture(&fixture);
            let tag = api::read_with_options(fixture.path(), true, true, false, false).unwrap();
            assert_eq!(tag.title.as_deref(), Some("Title"));
            assert_eq!(tag.artists, vec!["Artist A", "Artist B"]);
            assert!(tag.sample_rate.is_some());
            assert!(tag.lyrics.is_none());
            assert!(tag.pictures.is_empty());
        }
    }

    #[test]
    fn artwork_only_prefers_front_cover_and_full_read_remains_available() {
        for fixture in fixtures() {
            tagged_fixture(&fixture);
            let cover = api::read_artwork(fixture.path()).unwrap().unwrap();
            assert_eq!(
                cover.bytes,
                if fixture.0.extension().unwrap() == "m4a" {
                    vec![9, 8, 7]
                } else {
                    vec![1, 2, 3]
                }
            );
            let full = api::read(fixture.path()).unwrap();
            assert_eq!(full.lyrics.as_deref(), Some("Lyrics"));
            assert_eq!(full.pictures.len(), 2);
            let pictures =
                api::read_with_options(fixture.path(), false, false, false, true).unwrap();
            assert!(pictures.title.is_none());
            assert!(pictures.duration.is_none());
            assert_eq!(pictures.pictures.len(), 2);
        }
    }

    #[test]
    fn clearing_tags_removes_artwork_and_io_errors_are_not_absence() {
        for fixture in fixtures() {
            assert!(api::read_artwork(fixture.path())
                .unwrap_or_else(|error| panic!("initial {}: {error:?}", fixture.path()))
                .is_none());
            tagged_fixture(&fixture);
            api::write(fixture.path(), Tag::default()).unwrap();
            if let Ok(tag) = api::read(fixture.path()) {
                assert!(tag.title.is_none());
                assert!(tag.pictures.is_empty());
            }
            let properties =
                api::read_with_options(fixture.path(), false, true, false, false).unwrap();
            assert!(properties.sample_rate.is_some());
            assert!(api::read_artwork(fixture.path())
                .unwrap_or_else(|error| panic!("{}: {error:?}", fixture.path()))
                .is_none());
        }
        assert!(api::read_artwork("/missing/audiotags-test.mp3".into()).is_err());
    }

    #[test]
    #[ignore = "manual comparison; no timing threshold on shared CI hosts"]
    fn large_cover_scan_benchmark() {
        use std::{hint::black_box, time::Instant};
        let fixture = Fixture::new("flac", include_bytes!("../../test/fixtures/silence.flac"));
        api::write(
            fixture.path(),
            Tag {
                title: Some("Benchmark".into()),
                pictures: vec![Picture::new(
                    PictureType::CoverFront,
                    Some(MimeType::Jpeg),
                    vec![1; 4 * 1024 * 1024],
                )],
                ..Default::default()
            },
        )
        .unwrap();
        let iterations = 30;
        black_box(api::read(fixture.path()).unwrap());
        let start = Instant::now();
        for _ in 0..iterations {
            black_box(api::read(fixture.path()).unwrap());
        }
        let full = start.elapsed();
        let start = Instant::now();
        for _ in 0..iterations {
            let tag = api::read_with_options(fixture.path(), true, true, false, false).unwrap();
            assert!(tag.pictures.is_empty());
            black_box(tag);
        }
        let scan = start.elapsed();
        println!(
            "4MiB embedded cover, {iterations} cached FLAC reads: full={full:?}, scan={scan:?}"
        );
    }
}
