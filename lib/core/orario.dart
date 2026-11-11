/// L'ora in cifre, «21:40»: la stessa ovunque (schede, impostazioni, titoli in attesa).
String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
