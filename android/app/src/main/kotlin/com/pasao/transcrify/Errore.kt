package com.pasao.transcrify

/**
 * Un errore da mostrare a una persona: ogni anello della catena, «Tipo: messaggio», dal primo alla causa.
 * Senza, un errore all'avvio di un oggetto arriva come «ExceptionInInitializerError» e basta: la causa vera
 * (es. un'espressione che Android non capisce) sta sotto, in [Throwable.cause].
 */
fun Throwable.perLeggere(): String = generateSequence(this) { it.cause.takeIf { c -> c !== it } }
    .take(MAX_CAUSE)
    .joinToString(" ← ") { e -> e.javaClass.simpleName + (e.message?.let { ": ${it.lineSequence().first()}" } ?: "") }

/** Oltre tante cause non si scende: bastano per capire, e la catena non gira in tondo. */
private const val MAX_CAUSE = 4
