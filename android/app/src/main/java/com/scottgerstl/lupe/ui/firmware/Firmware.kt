package com.scottgerstl.lupe.ui.firmware

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.view.WindowManager
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.FirmwareCancelOffer
import com.scottgerstl.lupe.core.FirmwareClose
import com.scottgerstl.lupe.core.FirmwareInstall
import com.scottgerstl.lupe.core.FirmwareOffer
import com.scottgerstl.lupe.core.FirmwareState
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.firmwareWords
import com.scottgerstl.lupe.ui.shell.Key
import com.scottgerstl.lupe.ui.shell.KeyLabel
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import java.io.File

// Installing Skiff-Lupe from the phone (decision 42; the iPhone's FirmwareInstall.swift for the wording and the flow). The core (P1's fe3faaf) decides what is
// offered and says it in ready words; this draws: the offer card, the song-name menu's firmware sheet, the confirm (the real gate: the firmware intents are not
// behind the read-only gate), and the install cover over everything while it runs. Tested against the fake loader only.

/** What the phone shows beyond the core's own state: the menu's sheet, the confirm and where it is, "not now" for this run. */
class FirmwareHost {
    var info by mutableStateOf(false)
    /** The firmware being confirmed ([FirmwareOffer.firmware], or null for the core's default), or "" when not confirming. */
    var confirming by mutableStateOf<String?>(null)
    var confirmingOpen by mutableStateOf(false)
    /** Why the install can't start now, said in place (the battery). */
    var note by mutableStateOf<String?>(null)
    /** Offers whose "Not now" was pressed (the key) this run; the 14 days are in [FirmwarePrefs]. */
    val dismissed = mutableStateOf(setOf<String>())
    fun confirm(firmware: String?) { confirming = firmware; confirmingOpen = true; note = null; info = false }
    fun cancelConfirm() { confirmingOpen = false; note = null }
}

val LocalFirmwareHost = androidx.compose.runtime.staticCompositionLocalOf<FirmwareHost?> { null }

/** "Not now" for 14 days per offer key (the core hides the offer only until the FM-1 is unplugged). */
class FirmwarePrefs(context: Context) {
    private val prefs = context.getSharedPreferences("lupe_settings", Context.MODE_PRIVATE)
    fun snoozed(key: String, now: Long = System.currentTimeMillis()): Boolean = now < prefs.getLong("fw_not_now_$key", 0L)
    fun snooze(key: String, now: Long = System.currentTimeMillis()) { prefs.edit().putLong("fw_not_now_$key", now + SNOOZE_MS).apply() }
    companion object { const val SNOOZE_MS = 14L * 24 * 3600 * 1000 }
}

/** The phone's battery for the install's gate: level 0…100 and whether it is charging. Null level when it can't be read. */
fun batteryNow(context: Context): Pair<Int?, Boolean> {
    val i = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    val level = i?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
    val scale = i?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
    val plugged = (i?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0
    return (if (level >= 0 && scale > 0) level * 100 / scale else null) to plugged
}

/** Why the install can't start for the battery (as the iPad says it), or null. */
fun batteryRefusal(level: Int?, charging: Boolean): String? =
    if (level != null && !charging && level < 30)
        "Charge the phone first: it's at $level%. The phone powers the FM-1 while it writes, so Lupe installs below 30% only while charging." else null

private val VERSION = Regex("""\d+(?:\.\d+)+""")

/**
 * The firmware the FM-1 runs, by name: "Skiff-Lupe 2.5.1", "Skiff 2.6", "SLOOP 2.8.4", M-VAVE's own. The core's [FirmwareState.running] may give only a version
 * ("v2.5.1") when the FM-1 is on Skiff-Lupe, so the offer's origin (and no offer at all, on a connected FM-1) names it. Null when no FM-1 is known.
 */
fun firmwareName(fw: FirmwareState): String? {
    val running = fw.running?.trim()?.takeIf { it.isNotEmpty() } ?: fw.identity?.trim()?.takeIf { it.isNotEmpty() } ?: return null
    val version = VERSION.find(running)?.value
    val named = running.contains("skiff", true) || running.contains("sloop", true) || running.contains("vave", true) || running.contains("update", true)
    if (named) return running
    return when (fw.offer?.from) {
        "stockSkiff", "newerSkiff" -> "Skiff" + (version?.let { " $it" } ?: "")
        "olderLupe" -> "Skiff-Lupe" + (version?.let { " $it" } ?: "")
        "sloop" -> "SLOOP" + (version?.let { " $it" } ?: "")
        null -> if (version != null && fw.running != null) "Skiff-Lupe $version" else running      // a connected FM-1 with nothing on offer runs Skiff-Lupe
        else -> running
    }
}

/** The menu's second line and the sheet's first: the name, and what can be done about it ("Skiff-Lupe 2.5.1 · up to date", "Skiff 2.6 · Skiff-Lupe available"). */
fun firmwareLine(fw: FirmwareState): String {
    val name = firmwareName(fw) ?: return "What the FM-1 runs, and Skiff-Lupe"
    val offer = fw.offer
    return when (offer?.kind) {
        null -> if (fw.running != null && name.startsWith("Skiff-Lupe")) "$name · up to date" else name   // (stock Skiff after Not now: just its name)
        "install", "update" -> "$name · Skiff-Lupe available"
        "finish" -> "$name · waiting to finish an install"
        else -> name
    }
}

/** The word on the offer's main key. */
fun offerKeyTitle(kind: String): String = when (kind) { "update" -> "Install the update"; "finish" -> "Finish installing"; else -> "Install Skiff-Lupe" }

/** What the cover says it is doing, for each state. */
fun doing(state: String, installing: String?): String = when (state) {
    "downloading" -> "Downloading ${firmwareWords(installing)} from GitHub"
    "backingUp" -> "Backing up"
    "staging" -> "Checking the firmware file"
    "writing" -> "Writing the firmware"
    "resuming" -> "Writing again"
    "restarting" -> "Restarting the FM-1"
    "done" -> "Done"
    else -> ""
}

/** The whole firmware layer: the cover while it runs (over everything), else the confirm, the menu's sheet or the offer card. Draws nothing when there is none. */
@Composable
fun FirmwareLayer(core: LupeCore, host: FirmwareHost) {
    val fw by core.firmware.collectAsStateWithLifecycle()
    val ctx = LocalContext.current
    val prefs = remember { FirmwarePrefs(ctx) }
    // the screen stays on while the install runs
    DisposableEffect(fw.busy) {
        val w = (ctx as? Activity)?.window
        if (fw.busy) w?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        onDispose { if (fw.busy) w?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) }
    }
    // no way out by the back gesture while it runs
    BackHandler(enabled = fw.busy) { }
    var sawBackup by remember { mutableStateOf(false) }
    LaunchedEffect(fw.state) { if (fw.state == "backingUp") sawBackup = true else if (fw.state == "idle") sawBackup = false }

    val offer = fw.offer
    val offerShown = offer != null && !host.confirmingOpen && !host.info && offer.key !in host.dismissed.value && !prefs.snoozed(offer.key)
    val layer = when {
        fw.active -> "cover"
        host.confirmingOpen -> "confirm"
        host.info -> "info"
        offerShown -> "offer"
        else -> "none"
    }
    LupeCrossfade(layer, Modifier.fillMaxSize(), Dur.PANEL) { which ->
        when (which) {
            "cover" -> Cover(fw, core, host, sawBackup)
            "confirm" -> Scrim { ConfirmCard(fw, core, host) }
            "info" -> Scrim(onTapOutside = { host.info = false }) { InfoCard(fw, host) }
            "offer" -> if (offer != null) Scrim { OfferCard(offer, core, host, prefs) }
            else -> Unit
        }
    }
}

/** A dimmed page with the card in the middle; the page behind takes no touches. */
@Composable
private fun Scrim(onTapOutside: (() -> Unit)? = null, content: @Composable () -> Unit) {
    Box(
        Modifier.fillMaxSize().background(Tok.page.copy(alpha = 0.72f)).pointerInput(onTapOutside) { detectTapGestures { onTapOutside?.invoke() } }
            .windowInsetsPadding(WindowInsets.safeDrawing).padding(16.dp),
        contentAlignment = Alignment.Center,
    ) { Box(Modifier.pointerInput(Unit) { detectTapGestures { } }) { content() } }
}

@Composable
private fun CardFrame(title: String, buttons: @Composable () -> Unit, body: @Composable () -> Unit) {
    Column(
        Modifier.widthIn(max = 560.dp).fillMaxWidth().background(Tok.held, RoundedCornerShape(12.dp)).padding(16.dp)
            .semantics { liveRegion = LiveRegionMode.Polite },
    ) {
        BasicText(title, Modifier.semantics { heading() }, style = LupeType.title)
        Column(Modifier.weight(1f, fill = false).heightCap().verticalScroll(rememberScrollState()).padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { body() }
        Row(Modifier.fillMaxWidth().padding(top = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.End)) { buttons() }
    }
}

private fun Modifier.heightCap(): Modifier = this.then(Modifier.heightIn(max = 220.dp))

@Composable private fun Body(text: String, primary: Boolean = false) = BasicText(text, style = LupeType.body.copy(color = if (primary) Tok.text else Tok.text2Raised))

@Composable
private fun CardKey(title: String, primary: Boolean = false, enabled: Boolean = true, onClick: () -> Unit) =
    // (sized to the label, 16 dp each side, at least 88 wide: a fixed 48 dp key cut "Not now" and "Install Skiff-Lupe 2.5.1"
    // to "Not…" and "Inst…" on the Pixel 7, 2026-11-16)
    Key(onClick, title, Modifier.widthIn(min = 88.dp).width(IntrinsicSize.Max), minTarget = 48.dp, on = primary, enabled = enabled, fill = true) { fg ->
        KeyLabel(title, fg, Modifier.padding(horizontal = 16.dp), style = LupeType.key.copy(fontSize = 15.sp))
    }

/** The offer: what the FM-1 runs and what Lupe can do about it, in the core's words; Install (to the confirm) or Not now (14 days). */
@Composable
private fun OfferCard(offer: FirmwareOffer, core: LupeCore, host: FirmwareHost, prefs: FirmwarePrefs) {
    CardFrame(offer.title, buttons = {
        if (offer.kind == "foreign") CardKey("OK", primary = true) { host.dismissed.value = host.dismissed.value + offer.key }
        else {
            CardKey("Not now") { prefs.snooze(offer.key); host.dismissed.value = host.dismissed.value + offer.key; core.send(FirmwareCancelOffer) }
            CardKey(offerKeyTitle(offer.kind), primary = true) { host.confirm(offer.firmware) }
        }
    }) { Body(offer.text) }
}

/** The song-name menu's "FM-1 firmware…": what the FM-1 runs, what is on offer, Install. */
@Composable
private fun InfoCard(fw: FirmwareState, host: FirmwareHost) {
    val offer = fw.offer
    CardFrame("FM-1 firmware", buttons = {
        CardKey("Close") { host.info = false }
        if (offer != null && offer.firmware != null) CardKey(offerKeyTitle(offer.kind), primary = true) { host.confirm(offer.firmware) }
    }) {
        Body(firmwareLine(fw).takeIf { firmwareName(fw) != null } ?: "No FM-1 is connected.", primary = true)
        if (offer != null) Body(offer.text)
        else if (fw.running != null) Body("Lupe works with this firmware: there is nothing to install.")
    }
}

/** The confirm: the real gate (the core takes the install without it only because this asks). Names the firmware, what it does, the time, and the battery in place. */
@Composable
private fun ConfirmCard(fw: FirmwareState, core: LupeCore, host: FirmwareHost) {
    val ctx = LocalContext.current
    val name = firmwareWords(host.confirming?.takeIf { it.isNotEmpty() })
    CardFrame("Install $name?", buttons = {
        CardKey("Cancel") { host.cancelConfirm() }
        CardKey("Install $name", primary = true) {
            val (level, charging) = batteryNow(ctx)
            val why = batteryRefusal(level, charging)
            if (why != null) host.note = why
            else { core.send(FirmwareInstall(host.confirming?.takeIf { it.isNotEmpty() }, confirmed = true, battery = level, charging = charging)); host.cancelConfirm() }
        }
    }) {
        Body("This rewrites the FM-1's firmware with $name. It takes about a minute and the FM-1 restarts.", primary = true)
        Body("Keep the FM-1 plugged in, keep Lupe open and don't lock the phone while it writes. Lupe backs up the FM-1's projects, settings, presets and samples to the phone first, when the FM-1 is connected.")
        Body("If it's cut off anyway, nothing is lost: the FM-1 waits in update mode and running the install again finishes it.")
        host.note?.let { BasicText(it, Modifier.semantics { liveRegion = LiveRegionMode.Assertive }, style = LupeType.body.copy(color = Tok.rec)) }
    }
}

/** Over everything while it runs: the step, the progress, what to do. Done and failed say what happened and what to do next. */
@Composable
private fun Cover(fw: FirmwareState, core: LupeCore, host: FirmwareHost, sawBackup: Boolean) {
    val ctx = LocalContext.current
    Column(
        Modifier.fillMaxSize().background(Tok.page).pointerInput(Unit) { detectTapGestures { } }.windowInsetsPadding(WindowInsets.safeDrawing).padding(24.dp)
            .verticalScroll(rememberScrollState()).semantics { liveRegion = LiveRegionMode.Polite },
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        when (fw.state) {
            "done" -> {
                BasicText("${firmwareWords(fw.installing)} is installed", Modifier.semantics { heading() }, style = LupeType.title.copy(fontSize = 26.sp))
                Body(fw.message.ifEmpty { "The FM-1 restarted." }, primary = true)
                fw.backup?.let { BackupLine(it, ctx) }
                Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.End)) { CardKey("Done", primary = true) { core.send(FirmwareClose) } }
            }
            "failed" -> {
                BasicText("The install stopped", Modifier.semantics { heading() }, style = LupeType.title.copy(fontSize = 26.sp))
                Body(fw.message.ifEmpty { "The install didn't finish." }, primary = true)
                if (fw.inUpdateMode) {
                    Body("Nothing is lost. The FM-1 waits in update mode (its screen says UPDATE MODE, or stays dark) until a write finishes.")
                    Body("1. Plug the FM-1 straight into the phone, without a hub or adapter chain if you can.")
                    Body("2. Tap Run the install again. It finds the update mode and finishes the write.")
                } else Body("The FM-1 still runs its firmware. Check the cable and try again.")
                fw.backup?.let { BackupLine(it, ctx) }
                Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.End)) {
                    CardKey("Close") { core.send(FirmwareClose) }
                    // after a failed backup only: go on without one, as the iPad offers
                    if (sawBackup && fw.backup == null) CardKey("Install without a backup") { send(core, ctx, fw, skipBackup = true) }
                    CardKey(if (fw.inUpdateMode) "Run the install again" else "Try again", primary = true) { send(core, ctx, fw, skipBackup = false) }
                }
            }
            else -> {
                BasicText(doing(fw.state, fw.installing), Modifier.semantics { heading() }, style = LupeType.title.copy(fontSize = 26.sp))
                BasicText("Keep Lupe open and the FM-1 plugged in.", style = LupeType.title.copy(fontSize = 18.sp))
                val p = animatedFloat(fw.progress.toFloat().coerceIn(0f, 1f), 250)
                Canvas(Modifier.fillMaxWidth().height(6.dp).semantics { }) {
                    drawRoundRect(Tok.control, size = size, cornerRadius = CornerRadius(3.dp.toPx()))
                    drawRoundRect(Tok.text, size = Size(size.width * p.value, size.height), cornerRadius = CornerRadius(3.dp.toPx()))
                }
                Row { BasicText(fw.message, Modifier.weight(1f), style = LupeType.small.copy(color = Tok.text2Raised)); BasicText("${(fw.progress * 100).toInt()}%", style = LupeType.number.copy(fontSize = 15.sp, color = Tok.text2Raised)) }
                Spacer(Modifier.height(4.dp))
                Body("Don't unplug it or lock the phone. If it's cut off anyway, nothing is lost: the FM-1 waits in update mode and running the install again finishes it.")
            }
        }
    }
}

private fun send(core: LupeCore, ctx: Context, fw: FirmwareState, skipBackup: Boolean) {
    val (level, charging) = batteryNow(ctx)
    core.send(FirmwareInstall(fw.offer?.firmware, confirmed = true, battery = level, charging = charging, skipBackup = skipBackup))
}

/** Where the backup is, and a key to share it (a FileProvider: the file is in the app's own files). */
@Composable
private fun BackupLine(path: String, ctx: Context) {
    val name = File(path).name
    Body("The backup taken first is saved in Lupe's files: $name.")
    CardKey("Share the backup") { shareBackup(ctx, path) }
}

fun shareBackup(ctx: Context, path: String) {
    val f = File(path)
    if (!f.exists()) return
    val uri = FileProvider.getUriForFile(ctx, "${ctx.packageName}.files", f)
    val send = Intent(Intent.ACTION_SEND).apply { type = "application/octet-stream"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }
    ctx.startActivity(Intent.createChooser(send, "Share the backup").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}
