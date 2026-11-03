package com.pasao.transcrify

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.NoteAdd
import androidx.compose.material.icons.rounded.Reply
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/*
 * Le carte del Floater (Figma B12, riga «7 · Finale», poi i cassetti): escono da sopra il registratore.
 * La carta dei vocali li mostra di fila, ognuno con la sua X; quella dell'ultima trascrizione si tocca e copia. Mentre registri con i vocali fuori, la carta si accende:
 * stai rispondendo a quei vocali (il pulitore li riceve come contesto).
 */

/**
 * I cassetti sopra il registratore (sua idea, 2 nov notte): uno per ogni carta che c'è. Con dei vocali, il loro
 * (l'icona dell'app) e accanto quello dell'ultima trascrizione; senza, solo quello dell'ultima. Tocchi un cassetto
 * e esce la sua carta; tocchi l'altro e si scambiano; tocchi quello aperto e la carta rientra.
 */
@Composable
internal fun Cassetti(svc: PillService, haUltima: Boolean) {
    val vocali = svc.vocali.isNotEmpty()
    // Una carta sola (l'ultima): il caret, come prima. Due carte: due bottoni, ognuno con la sua icona.
    if (!vocali) {
        Cassetto(svc, Carta.ULTIMA, "l'ultima trascrizione") { aperto -> Freccia(aperto) }
        return
    }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Cassetto(svc, Carta.VOCALI, if (svc.vocali.size > 1) "i vocali" else "il vocale") { IconaProvenienza(svc.vocali.first().second.source) }
        if (haUltima) Cassetto(svc, Carta.ULTIMA, "l'ultima trascrizione") { Icon(CopyAgain, null, tint = Palette.Text, modifier = Modifier.size(16.dp)) }
    }
}

@Composable
private fun Freccia(aperto: Boolean) {
    val giro by animateFloatAsState(if (aperto) 180f else 0f, label = "freccia")
    Icon(Icons.Rounded.ExpandLess, null, tint = Palette.Text, modifier = Modifier.size(18.dp).rotate(giro))
}

/** Un cassetto: tutti uguali, il contenuto al centro; acceso quando la sua carta è fuori. */
@Composable
private fun Cassetto(svc: PillService, quale: Carta, nome: String, contenuto: @Composable (aperto: Boolean) -> Unit) {
    val aperto = svc.carta == quale
    Box(
        Modifier
            .size(CASSETTO_W, 28.dp)
            .clip(Forme.pillola)
            .background(Palette.Text.copy(alpha = if (aperto) 0.26f else 0.12f))
            .clickable(onClickLabel = if (aperto) "Chiudi $nome" else "Apri $nome") { svc.carta = if (aperto) null else quale },
        contentAlignment = Alignment.Center,
    ) { contenuto(aperto) }
}

@Composable
internal fun CartaFuori(svc: PillService, quale: Carta, maxAltezza: Dp) {
    val risponde = svc.session.phase == Phase.RECORDING
    val vocali = svc.vocali
    val dei = quale == Carta.VOCALI && vocali.isNotEmpty()
    Column(
        Modifier
            .fillMaxWidth()
            .clip(Forme.scheda)
            .background(Palette.Carta)
            .then(if (risponde && dei) Modifier.border(2.dp, Palette.Blue, Forme.scheda) else Modifier),
    ) {
        if (dei) CartaVocali(svc, vocali, risponde, maxAltezza) else CartaUltima(svc)
    }
}

@Composable
private fun CartaVocali(svc: PillService, vocali: List<Pair<Transcription, Origin>>, risponde: Boolean, maxAltezza: Dp) {
    Testata(vocali, risponde)
    Column(
        Modifier
            .heightIn(max = maxAltezza)
            .verticalScroll(rememberScrollState())
            .padding(start = 12.dp, end = 4.dp, top = 4.dp, bottom = 10.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        vocali.forEach { (t, _) -> Vocale(svc, t) }
    }
    Linea()
    val tutteNote = vocali.all { it.first.noteId != null }
    ComandiCarta {
        if (tutteNote) Comando(Icons.Rounded.Check, "Nelle note") {}
        else Comando(Icons.Rounded.NoteAdd, if (vocali.size > 1) "Salva come note" else "Salva come nota") { svc.vocaliInNote() }
    }
}

/**
 * La testata della carta, col suo colore: da dove arrivano i vocali («Vocale di WhatsApp», «3 vocali di WhatsApp»).
 * Quando registri con la carta fuori diventa «Stai rispondendo…», piena: è la stessa striscia che cambia.
 */
@Composable
private fun Testata(vocali: List<Pair<Transcription, Origin>>, risponde: Boolean) {
    val ctx = LocalContext.current
    val primo = vocali.first().second
    val app = Provenienza.nome(ctx, primo.source)
    val stessaApp = vocali.all { it.second.source == primo.source }
    val titolo = when {
        risponde -> if (vocali.size > 1) "Stai rispondendo a questi vocali" else "Stai rispondendo a questo vocale"
        vocali.size == 1 -> Provenienza.titolo(ctx, primo)
        app != null && stessaApp -> "${vocali.size} vocali di $app"
        else -> "${vocali.size} vocali"
    }
    val testo = if (risponde) Palette.Ink else Palette.SuCarta
    Row(
        Modifier.fillMaxWidth().background(if (risponde) Palette.Blue else Palette.TestataCarta).padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (risponde) Icon(Icons.Rounded.Reply, null, tint = testo, modifier = Modifier.size(16.dp)) else IconaProvenienza(primo.source)
        Spacer(Modifier.width(6.dp))
        Text(titolo, style = Caratteri.etichetta.copy(color = testo), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** Un vocale sulla carta: l'ora e la sua X (lo togli, gli altri salgono), poi il testo. */
@Composable
private fun Vocale(svc: PillService, t: Transcription) {
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(ORA.format(Date(t.at)), Modifier.weight(1f), style = Caratteri.orario.copy(color = Palette.SuCartaTenue))
            Box(
                Modifier.size(32.dp).clip(CircleShape).clickable(onClickLabel = "Togli questo vocale") { svc.togliVocale(t) },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.Close, null, tint = Palette.SuCartaTenue, modifier = Modifier.size(16.dp)) }
        }
        Text(t.text, Modifier.padding(end = 8.dp), style = Caratteri.testo.copy(color = Palette.SuCarta))
    }
}

/** L'ultima trascrizione: toccandola la copi (niente menu: lo dice già la carta). */
@Composable
private fun CartaUltima(svc: PillService) {
    val s = svc.session
    val testo = remember(s.phase, s.hasLast) { s.lastText() } ?: return
    var copiata by remember { mutableStateOf(false) }
    LaunchedEffect(copiata) {
        if (copiata) {
            kotlinx.coroutines.delay(Durate.CONFERMA)
            copiata = false
        }
    }
    Column(
        Modifier
            .fillMaxWidth()
            .clickable(onClickLabel = "Copia l'ultima trascrizione") {
                s.copyLast()
                copiata = true
            }
            .padding(horizontal = 12.dp, vertical = 10.dp),
    ) {
        Text(if (copiata) "Copiata ✓" else "Ultima · tocca per copiare", style = Caratteri.orario.copy(color = if (copiata) Palette.Green else Palette.SuCartaTenue))
        Spacer(Modifier.height(2.dp))
        Text(testo, style = Caratteri.testo.copy(color = Palette.SuCarta), maxLines = 4, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun Linea() = Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.LineaCarta))

@Composable
private fun ComandiCarta(content: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 6.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) { content() }
}

@Composable
private fun Comando(icona: ImageVector, testo: String, onClick: () -> Unit) {
    Row(
        Modifier.clip(Forme.pillola).clickable(onClickLabel = testo, onClick = onClick).padding(horizontal = 8.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icona, null, tint = Palette.SuCartaTenue, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(4.dp))
        Text(testo, style = Caratteri.piccolo.copy(color = Palette.SuCarta))
    }
}

/** L'icona vera dell'app da cui arriva l'audio; se non la conosciamo, l'onda. */
@Composable
private fun IconaProvenienza(source: String?) {
    val ctx = LocalContext.current
    val icona = remember(source) { Provenienza.icona(ctx, source)?.asImageBitmap() }
    if (icona != null) Image(icona, null, Modifier.size(16.dp).clip(CircleShape))
    else Icon(Icons.Rounded.GraphicEq, null, tint = Palette.SuCartaTenue, modifier = Modifier.size(16.dp))
}

private val ORA = SimpleDateFormat("HH:mm", Locale.ITALIAN)
private val CASSETTO_W = 56.dp
