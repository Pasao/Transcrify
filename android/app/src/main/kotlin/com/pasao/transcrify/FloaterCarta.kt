package com.pasao.transcrify

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
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
import androidx.compose.ui.graphics.Color
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

/** Il contenuto della carta di [quale]: il fondo e il contorno sono della forma che cresce dal cassetto (CarteFuse). */
@Composable
internal fun CartaFuori(svc: PillService, quale: Carta, maxAltezza: Dp) {
    val risponde = svc.session.phase == Phase.RECORDING
    val vocali = svc.vocali
    Column(Modifier.fillMaxWidth()) {
        when {
            quale == Carta.VOCALI && vocali.isNotEmpty() -> CartaVocali(svc, vocali, risponde, maxAltezza)
            quale == Carta.PAUSA -> CartaPausa(svc.session)
            else -> CartaUltima(svc)
        }
    }
}

/**
 * Dove eri arrivato: in pausa da un po', la fine di quello che hai detto (trascritto una volta, solo per farlo
 * vedere). Senza rete, o finché non arriva, solo il tempo.
 */
@Composable
private fun CartaPausa(s: Session) {
    val sec = s.elapsedMs / 1000
    Column(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp)) {
        Text("In pausa · %d:%02d".format(sec / 60, sec % 60), style = Caratteri.orario.copy(color = Palette.SuCartaTenue))
        s.bozza?.let {
            Spacer(Modifier.height(2.dp))
            Text(Bozza.coda(it), style = Caratteri.testo.copy(color = Palette.SuCarta), maxLines = 4, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
private fun CartaVocali(svc: PillService, vocali: List<Pair<Transcription, Origin>>, risponde: Boolean, maxAltezza: Dp) {
    Testata(vocali, risponde) { svc.togliVocali() }
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
 * La sua X toglie tutti i vocali dalla carta; ognuno, nella lista, ha ancora la sua.
 */
@Composable
private fun Testata(vocali: List<Pair<Transcription, Origin>>, risponde: Boolean, togliTutti: () -> Unit) {
    val ctx = LocalContext.current
    val primo = vocali.first().second
    val app = Provenienza.nome(ctx, primo.source)
    val stessaApp = vocali.all { it.second.source == primo.source }
    val titolo = when {
        risponde -> if (vocali.size > 1) "Stai rispondendo a questi vocali" else "Stai rispondendo a questo vocale"
        else -> Provenienza.testata(vocali.size, app.takeIf { stessaApp }, Provenienza.titolo(ctx, primo))
    }
    val testo = if (risponde) Palette.Ink else Palette.SuCarta
    Row(
        Modifier.fillMaxWidth().background(if (risponde) Palette.Blue else Palette.TestataCarta).padding(start = 12.dp, end = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (risponde) Icon(Icons.Rounded.Reply, null, tint = testo, modifier = Modifier.size(16.dp)) else IconaProvenienza(primo.source)
        Spacer(Modifier.width(6.dp))
        Text(titolo, Modifier.weight(1f), style = Caratteri.etichetta.copy(color = testo), maxLines = 1, overflow = TextOverflow.Ellipsis)
        Chiudi(if (vocali.size > 1) "Togli tutti i vocali" else "Togli il vocale", testo, togliTutti)
    }
}

/** Una X tonda sulla carta, col suo nome per chi non vede. */
@Composable
private fun Chiudi(nome: String, tinta: Color, onClick: () -> Unit) {
    Box(Modifier.size(32.dp).clip(CircleShape).clickable(onClickLabel = nome, onClick = onClick), contentAlignment = Alignment.Center) {
        Icon(Icons.Rounded.Close, null, tint = tinta, modifier = Modifier.size(16.dp))
    }
}

/** Un vocale sulla carta: l'ora e la sua X (lo togli, gli altri salgono), poi il testo. */
@Composable
private fun Vocale(svc: PillService, t: Transcription) {
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(ORA.format(Date(t.at)), Modifier.weight(1f), style = Caratteri.orario.copy(color = Palette.SuCartaTenue))
            Chiudi("Togli questo vocale", Palette.SuCartaTenue) { svc.togliVocale(t) }
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
    val copia = {
        s.copyLast()
        copiata = true
    }
    Column(
        Modifier
            .fillMaxWidth()
            .clickable(onClickLabel = "Copia l'ultima trascrizione", onClick = copia)
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
internal fun IconaProvenienza(source: String?) {
    val ctx = LocalContext.current
    val icona = remember(source) { Provenienza.icona(ctx, source)?.asImageBitmap() }
    if (icona != null) Image(icona, null, Modifier.size(16.dp).clip(CircleShape))
    else Icon(Icons.Rounded.GraphicEq, null, tint = Palette.SuCartaTenue, modifier = Modifier.size(16.dp))
}

private val ORA = SimpleDateFormat("HH:mm", Locale.ITALIAN)
