package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.shell.sceneScrollTarget
import org.junit.Assert.assertEquals
import org.junit.Test

class SceneRowTest {
    @Test fun theCurrentSceneIsCentredAndTheEndsClamp() {
        assertEquals(0, sceneScrollTarget(0, 56f, 340, 500))      // the first scene: already at the start
        assertEquals(500, sceneScrollTarget(15, 56f, 340, 500))   // the last: stops at the end
        assertEquals(56 * 8 + 28 - 170, sceneScrollTarget(8, 56f, 340, 500))   // in the middle: centred
    }
}
