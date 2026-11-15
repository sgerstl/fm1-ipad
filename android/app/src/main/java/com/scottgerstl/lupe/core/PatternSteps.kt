package com.scottgerstl.lupe.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * The pattern's step count (batch item 9: the FM-1's LENGTH, Skiff's P_SLEN, 1…[EditorState.patternStepsMax]). Edit's STEPS key sends it,
 * and follows the FM-1's own LENGTH knob through [EditorState.patternSteps]. A write: PhoneCore refuses it while read-only.
 */
@Serializable @SerialName("setPatternSteps") data class SetPatternSteps(val steps: Int) : Intent
