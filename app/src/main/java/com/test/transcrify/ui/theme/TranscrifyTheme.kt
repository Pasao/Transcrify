package com.test.transcrify.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.Typography // Importa Typography da M3
import androidx.compose.material3.Shapes // Importa Shapes da M3
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat

// --- Definizioni Colori ---
// Sostituisci questi con i colori del tuo brand!
// Puoi generare una palette qui: https://material-foundation.github.io/material-theme-builder/

private val LightColorScheme = lightColorScheme(
    primary = Color(0xFF6200EE), // Esempio: Viola
    onPrimary = Color.White,
    primaryContainer = Color(0xFFBB86FC),
    onPrimaryContainer = Color(0xFF3700B3),
    secondary = Color(0xFF03DAC6), // Esempio: Teal
    onSecondary = Color.Black,
    secondaryContainer = Color(0xFF018786),
    onSecondaryContainer = Color.White,
    tertiary = Color(0xFF03A9F4), // Esempio: Light Blue
    onTertiary = Color.Black,
    tertiaryContainer = Color(0xFFB3E5FC),
    onTertiaryContainer = Color(0xFF01579B),
    error = Color(0xFFB00020),
    onError = Color.White,
    errorContainer = Color(0xFFFCD8DF),
    onErrorContainer = Color(0xFFB00020),
    background = Color(0xFFFFFFFF), // Sfondo chiaro standard
    onBackground = Color(0xFF1C1B1F), // Testo/Icone su sfondo chiaro
    surface = Color(0xFFFFFBFE), // Superficie componenti chiara
    onSurface = Color(0xFF1C1B1F), // Testo/Icone su superficie chiara
    surfaceVariant = Color(0xFFE7E0EC),
    onSurfaceVariant = Color(0xFF49454F),
    outline = Color(0xFF79747E)
)

private val DarkColorScheme = darkColorScheme(
    primary = Color(0xFFBB86FC), // Esempio: Viola più chiaro per contrasto su scuro
    onPrimary = Color(0xFF3700B3),
    primaryContainer = Color(0xFF6200EE),
    onPrimaryContainer = Color(0xFFEDE7F6),
    secondary = Color(0xFF03DAC6), // Esempio: Teal (può rimanere uguale o schiarirsi)
    onSecondary = Color.Black,
    secondaryContainer = Color(0xFF018786),
    onSecondaryContainer = Color(0xFFE0F2F7),
    tertiary = Color(0xFF81D4FA), // Esempio: Light blue più chiaro
    onTertiary = Color(0xFF01579B),
    tertiaryContainer = Color(0xFF03A9F4),
    onTertiaryContainer = Color(0xFFE1F5FE),
    error = Color(0xFFCF6679),
    onError = Color(0xFF141213),
    errorContainer = Color(0xFFB00020),
    onErrorContainer = Color(0xFFFCD8DF),
    background = Color(0xFF121212), // Sfondo scuro standard
    onBackground = Color(0xFFE6E1E5), // Testo/Icone su sfondo scuro
    surface = Color(0xFF1C1B1F), // Superficie componenti scura
    onSurface = Color(0xFFE6E1E5), // Testo/Icone su superficie scura
    surfaceVariant = Color(0xFF49454F),
    onSurfaceVariant = Color(0xFFCAC4D0),
    outline = Color(0xFF938F99)
)

// --- Definizione Tipografia ---
// Qui puoi definire font custom, pesi, dimensioni etc.
// Vedi: https://developer.android.com/jetpack/compose/designsystems/material3/typography
val AppTypography = Typography(
    bodyLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.5.sp
    ),
    titleLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Bold, // Esempio: Titolo in grassetto
        fontSize = 22.sp,
        lineHeight = 28.sp,
        letterSpacing = 0.sp
    ),
    labelSmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize = 11.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp
    )
    /* Aggiungi altri stili di testo di cui hai bisogno (bodyMedium, titleMedium, etc.) */
)

// --- Definizione Forme ---
// Angoli arrotondati per i componenti
val AppShapes = Shapes(
    small = androidx.compose.foundation.shape.RoundedCornerShape(4.dp),
    medium = androidx.compose.foundation.shape.RoundedCornerShape(8.dp), // Angolo comune per Card, Button
    large = androidx.compose.foundation.shape.RoundedCornerShape(16.dp)
)


// --- Funzione Theme Principale ---
@Composable
fun TranscrifyTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    // Dynamic color è disponibile su Android 12+
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        // Se dynamicColor è true E siamo su Android 12+...
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            // ...usa la palette dinamica generata dal sistema (chiara o scura)
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        // Altrimenti, se è darkTheme...
        darkTheme -> DarkColorScheme // ...usa la nostra palette scura definita sopra
        // Altrimenti (è tema chiaro)...
        else -> LightColorScheme // ...usa la nostra palette chiara definita sopra
    }

    // Gestione opzionale per colorare la barra di stato e di navigazione
    val view = LocalView.current
    if (!view.isInEditMode) { // Non eseguire nel preview dell'IDE
        SideEffect { // Esegui questo effetto collaterale quando il tema cambia
            val window = (view.context as Activity).window
            // Imposta il colore della status bar (trasparente o colore di sfondo)
            window.statusBarColor = colorScheme.background.toArgb() // o Color.Transparent.toArgb()
            // Imposta il colore della navigation bar (trasparente o colore di sfondo)
            window.navigationBarColor = colorScheme.background.toArgb() // o Color.Transparent.toArgb()

            // Imposta l'aspetto delle icone della status bar (chiare o scure)
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
            // Imposta l'aspetto delle icone della navigation bar (chiare o scure)
            WindowCompat.getInsetsController(window, view).isAppearanceLightNavigationBars = !darkTheme
        }
    }

    // Applica il tema Material
    MaterialTheme(
        colorScheme = colorScheme, // Applica la palette colori scelta
        typography = AppTypography, // Applica la tipografia definita
        shapes = AppShapes,         // Applica le forme definite
        content = content           // Renderizza il contenuto dell'app all'interno del tema
    )
}