package com.pasao.transcrify.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ColoreRegoleTest {
    private val soglia = 0.38f
    private val margine = 0.03f

    private fun decidi(regole: Map<String, Float>, vicine: List<Pair<String, Float>> = emptyList()) =
        ColoreRegole.decidi(regole, vicine, soglia, margine)

    @Test
    fun `la regola scritta da te basta, se somiglia e stacca le altre`() {
        assertEquals("2:4", decidi(mapOf("2:4" to 0.5f, "5:4" to 0.3f)))
        // Somiglia, ma poco: niente.
        assertNull(decidi(mapOf("2:4" to 0.35f, "5:4" to 0.1f)))
    }

    @Test
    fun `due colori quasi pari non vince nessuno`() {
        assertNull(decidi(mapOf("2:4" to 0.5f, "5:4" to 0.49f)))
        // Il secondo può essere anche un esempio colorato di un altro colore.
        assertNull(decidi(mapOf("2:4" to 0.5f), listOf("5:4" to 0.49f)))
        assertEquals("2:4", decidi(mapOf("2:4" to 0.5f), listOf("5:4" to 0.4f)))
    }

    @Test
    fun `senza regola, due vicine su tre d'accordo`() {
        assertEquals("2:4", decidi(emptyMap(), listOf("2:4" to 0.6f, "2:4" to 0.5f, "5:4" to 0.45f, "5:4" to 0.1f)))
        assertNull(decidi(emptyMap(), listOf("2:4" to 0.6f, "5:4" to 0.5f, "7:4" to 0.45f)))
        // Sotto la soglia non contano.
        assertNull(decidi(emptyMap(), listOf("2:4" to 0.6f, "2:4" to 0.3f, "2:4" to 0.2f)))
        assertNull(decidi(emptyMap(), emptyList()))
    }

    @Test
    fun `contano solo le tre più vicine`() {
        assertNull(decidi(emptyMap(), listOf("2:4" to 0.9f, "5:4" to 0.8f, "6:4" to 0.7f, "2:4" to 0.6f)))
    }

    @Test
    fun `la regola ha la sua soglia, più bassa di quella delle vicine`() {
        // Col modello vero (11 nov): la regola somiglia 0,62, sotto la soglia delle vicine (0,80) ma sopra la sua.
        assertEquals("2:4", ColoreRegole.decidi(mapOf("2:4" to 0.62f, "5:4" to 0.5f), emptyList(), 0.8f, margine, sogliaRegola = 0.56f))
        // Una vicina di un altro colore a 0,78 è sotto la sua soglia: non batte la regola che supera la sua.
        assertEquals("2:4", ColoreRegole.decidi(mapOf("2:4" to 0.62f), listOf("5:4" to 0.78f), 0.8f, margine, sogliaRegola = 0.56f))
        assertNull(ColoreRegole.decidi(mapOf("2:4" to 0.5f), emptyList(), 0.8f, margine, sogliaRegola = 0.56f))
    }

    @Test
    fun `la regola e gli esempi insieme`() {
        // Gli esempi di un altro colore sono più forti della regola: vincono loro.
        assertEquals("5:4", decidi(mapOf("2:4" to 0.4f), listOf("5:4" to 0.6f, "5:4" to 0.55f)))
        // Una regola che somiglia molto batte una vicina sola di un altro colore.
        assertEquals("2:4", decidi(mapOf("2:4" to 0.7f), listOf("5:4" to 0.5f)))
    }
}
