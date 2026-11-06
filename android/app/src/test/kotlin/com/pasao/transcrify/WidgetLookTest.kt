package com.pasao.transcrify

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Il 2 × 1 (6 nov, giro 6): le parole o il tondo che apre l'app; col tondo c'è anche senza la scritta. */
class WidgetLookTest {
    @Test
    fun ilDueXUnoCeConLeParoleOColTondo() {
        assertTrue(WidgetLook().dueXUno)
        assertTrue(WidgetLook(text = false, apri = true).dueXUno)
        assertFalse(WidgetLook(text = false).dueXUno)
    }

    @Test
    fun diBaseLeParole() = assertFalse(WidgetLook().apri)
}
