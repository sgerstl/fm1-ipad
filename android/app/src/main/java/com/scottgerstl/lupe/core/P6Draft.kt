package com.scottgerstl.lupe.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * DRAFT (P2, 2026-11-14): drawing on the automation lane. Each step the finger passes becomes a lock on [lane] at [value]
 * (0..100 of the lane's range); the FM-1 stores locks step by step. P1's `automation` schema may name this differently:
 * the screens only send it through [com.scottgerstl.lupe.ui.automation.AutomationActions].
 */
@Serializable @SerialName("automationDraw") data class AutomationDraw(val step: Int, val lane: String, val value: Int) : Intent
