package com.ryanheise.just_audio;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class PlaybackPositionClockTest {
    @Test
    public void detectsColdStartDelayWithoutASeek() {
        // Playback was restored at 30s, but output started 500ms late.
        assertTrue(AudioPlayer.positionClockDrifted(30500, 30000, 1000, 1.0f));
        // Broadcasting a fresh native sample removes the persistent lead.
        assertFalse(AudioPlayer.positionClockDrifted(31000, 30500, 500, 1.0f));
    }

    @Test
    public void acceptsNormalClockJitter() {
        assertFalse(AudioPlayer.positionClockDrifted(10950, 10000, 1000, 1.0f));
        assertFalse(AudioPlayer.positionClockDrifted(11050, 10000, 1000, 1.0f));
    }

    @Test
    public void accountsForPlaybackSpeed() {
        assertFalse(AudioPlayer.positionClockDrifted(12000, 10000, 1000, 2.0f));
        assertFalse(AudioPlayer.positionClockDrifted(10500, 10000, 1000, 0.5f));
        assertTrue(AudioPlayer.positionClockDrifted(11500, 10000, 1000, 2.0f));
    }

    @Test
    public void detectsDriftInEitherDirection() {
        assertTrue(AudioPlayer.positionClockDrifted(10500, 10000, 1000, 1.0f));
        assertTrue(AudioPlayer.positionClockDrifted(11500, 10000, 1000, 1.0f));
    }
}
