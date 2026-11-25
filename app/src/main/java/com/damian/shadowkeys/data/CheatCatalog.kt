package com.damian.shadowkeys.data

object CheatCatalog {
    const val PLAYER = "Jugador"
    const val WEAPONS = "Armas"
    const val VEHICLES = "Vehículos"
    const val WANTED = "Nivel policial"
    const val WORLD = "Mundo y tráfico"
    const val WEATHER = "Clima y hora"
    const val FUN = "Diversión"

    val categories = listOf(PLAYER, WEAPONS, VEHICLES, WANTED, WORLD, WEATHER, FUN)

    // Códigos publicados para la edición móvil de GTA San Andreas. La recepción
    // de cada código aún debe validarse en la compilación instalada en el dispositivo.
    val all: List<Cheat> = listOf(
        Cheat("Vida, chaleco y \$250 000", "PJYNQCQ", PLAYER, "Restaura la salud y el chaleco, añade dinero y repara el vehículo actual."),
        Cheat("Salud infinita", "BLOKKIK", PLAYER, "Evita el daño de balas y golpes; explosiones, caídas y ahogamiento todavía pueden afectar a CJ."),
        Cheat("Suicidio", "SLOTSFK", PLAYER, "Elimina inmediatamente a CJ."),
        Cheat("Grasa al máximo", "AESHXWQI", PLAYER, "Lleva la grasa de CJ al máximo."),
        Cheat("Músculo al máximo", "SGVDSQW", PLAYER, "Lleva el músculo de CJ al máximo."),
        Cheat("CJ delgado", "AWXDCRJ", PLAYER, "Reduce grasa y músculo al mínimo."),
        Cheat("Respeto máximo", "MTGIISR", PLAYER, "Completa el indicador de respeto."),
        Cheat("Atractivo máximo", "APGZLQR", PLAYER, "Completa el atractivo sexual."),
        Cheat("Resistencia máxima", "AEZLCKXU", PLAYER, "Completa la resistencia."),
        Cheat("Capacidad pulmonar infinita", "POOOJOX", PLAYER, "Permite permanecer bajo el agua sin quedarse sin aire."),
        Cheat("Nunca tiene hambre", "KBTMUVH", PLAYER, "CJ deja de necesitar comida."),
        Cheat("Invencibilidad completa", "GONPXWR", PLAYER, "Invencibilidad de la edición móvil de 2013; protege también los vehículos que utiliza CJ."),
        Cheat("Armas: conjunto 1", "BEFWKSBQ", WEAPONS, "Entrega el primer conjunto de armas.", "Puede sustituir el arma necesaria en la misión Air Raid."),
        Cheat("Armas: conjunto 2", "SHHIHJG", WEAPONS, "Entrega el segundo conjunto de armas.", "Puede afectar la misión Tagging Up Turf si se activa durante ella."),
        Cheat("Armas: conjunto 3", "GOIZSSX", WEAPONS, "Entrega el tercer conjunto de armas."),
        Cheat("Munición infinita", "NECUMZ", WEAPONS, "Munición ilimitada sin recargar.", "Puede provocar fallos de audio y afectar a peatones."),
        Cheat("Apuntar libremente al conducir", "RYSMRM", WEAPONS, "Permite apuntar desde vehículos y entrega un arma si hace falta."),
        Cheat("Armas: conjunto 4", "BIEUHQY", WEAPONS, "Conjunto móvil con minigun y gafas especiales."),
        Cheat("Aparecer con jetpack", "CDGUDEP", VEHICLES, "Entrega un jetpack."),
        Cheat("Aparecer con paracaídas", "GSUMLEG", VEHICLES, "Entrega un paracaídas."),
        Cheat("Aparecer con tanque Rhino", "AYNVQVK", VEHICLES, "Aparece un tanque Rhino."),
        Cheat("Aparecer con Hydra", "AWPTMIIQ", VEHICLES, "Aparece un avión Hydra."),
        Cheat("Aparecer con Bloodring Banger", "BIGLWCDD", VEHICLES, "Aparece un Bloodring Banger."),
        Cheat("Aparecer con Hotring Racer A", "BGJPSYC", VEHICLES, "Aparece el primer Hotring Racer."),
        Cheat("Aparecer con Hotring Racer B", "BIEAVBAY", VEHICLES, "Aparece el segundo Hotring Racer."),
        Cheat("Aparecer con Rancher", "HPGPIJZ", VEHICLES, "Aparece una Rancher."),
        Cheat("Aparecer con Romero", "PSPNATX", VEHICLES, "Aparece un coche fúnebre Romero."),
        Cheat("Aparecer con limusina", "IXSMWCQ", VEHICLES, "Aparece una limusina Stretch."),
        Cheat("Aparecer con Trashmaster", "QPOLSVK", VEHICLES, "Aparece un camión de basura."),
        Cheat("Aparecer con Caddy", "DAHESZY", VEHICLES, "Aparece un carrito de golf."),
        Cheat("Coche invencible", "BXBTUBTI", VEHICLES, "Tu coche resiste impactos y destruye los vehículos que toca."),
        Cheat("Destruir vehículos", "BKFONFE", VEHICLES, "Hace explotar los vehículos cercanos.", "Puede fallar misiones que dependen de un vehículo."),
        Cheat("Conducción perfecta", "DLNNHZJ", VEHICLES, "Mejora el agarre y el control de los coches."),
        Cheat("Nitro en todos los coches", "WUSDOTO", VEHICLES, "Instala nitro en todos los coches."),
        Cheat("Coches voladores", "DOTBSFK", VEHICLES, "Permite que los coches despeguen y vuelen."),
        Cheat("Barcos voladores", "PTHSEO", VEHICLES, "Permite que los barcos despeguen y vuelen."),
        Cheat("Coches sobre el agua", "BDBGXNJI", VEHICLES, "Permite conducir coches sobre el agua.", "La fuente indica que no está disponible en el lanzamiento original de PC; verificar en tu compilación."),
        Cheat("Coches salen volando al golpearlos", "JBVIJXA", VEHICLES, "Los vehículos se elevan cuando reciben impactos."),
        Cheat("Saltos enormes en bicicleta", "TDBKCEH", VEHICLES, "Aumenta enormemente los saltos de bicicleta."),
        Cheat("Nunca buscado", "BYKGOAB", WANTED, "Congela el nivel de búsqueda actual; no elimina estrellas existentes.", "Puede interferir con la misión Mike Toreno."),
        Cheat("Aumentar búsqueda", "NCBXXDX", WANTED, "Añade dos estrellas de búsqueda.", "Puede fallar la misión 555 We Tip si se activa durante ella."),
        Cheat("Eliminar búsqueda", "KDTZNHO", WANTED, "Elimina todas las estrellas de búsqueda."),
        Cheat("Seis estrellas", "GWJZWC", WANTED, "Establece el máximo nivel de búsqueda.", "Puede fallar la misión 555 We Tip si se activa durante ella."),
        Cheat("Semáforos siempre verdes", "ENQCFMA", WORLD, "Mantiene verdes los semáforos."),
        Cheat("Conductores agresivos", "IOKXTFJ", WORLD, "Los conductores circulan de forma agresiva."),
        Cheat("Tráfico negro", "GOYDVAO", WORLD, "La mayoría del tráfico se vuelve negro."),
        Cheat("Tráfico rosa", "GYKVYTR", WORLD, "La mayoría del tráfico se vuelve rosa."),
        Cheat("Tráfico de deportivos", "FRIUBIL", WORLD, "El tráfico se compone de coches deportivos."),
        Cheat("Tráfico de coches baratos", "JTBCSN", WORLD, "Aparecen coches antiguos y baratos."),
        Cheat("Tráfico reducido", "DEHDRX", WORLD, "Reduce peatones y tráfico."),
        Cheat("Disturbios de peatones", "NJXPCYE", WORLD, "Los peatones luchan por toda la ciudad.", "Puede quedar permanente al guardar y romper misiones. No guardes la partida con este truco activo."),
        Cheat("Modo caos", "AKOZBCH", WORLD, "Los peatones se atacan entre sí.", "Puede quedar permanente al guardar la partida."),
        Cheat("Peatones atacan a CJ", "FARYJHZ", WORLD, "Todos los peatones persiguen a CJ.", "Puede quedar permanente al guardar la partida."),
        Cheat("Peatones atacan con armas", "ERFBFNI", WORLD, "Los peatones armados atacan a CJ.", "Puede quedar permanente al guardar la partida."),
        Cheat("Peatones llevan armas", "GDNXHDK", WORLD, "Los peatones llevan armas variadas."),
        Cheat("Pandillas por todas partes", "EAMLJNN", WORLD, "Los miembros de las pandillas aparecen por toda la ciudad."),
        Cheat("Las pandillas controlan las calles", "HAPOHXR", WORLD, "Las pandillas dominan las calles y luchan entre sí."),
        Cheat("Tiempo soleado", "AAEXPPQC", WEATHER, "Activa tiempo soleado."),
        Cheat("Tiempo muy soleado", "HTRTTVJ", WEATHER, "Activa tiempo muy soleado y caluroso."),
        Cheat("Tiempo nublado", "VBWEMQX", WEATHER, "Activa cielo cubierto."),
        Cheat("Lluvia", "TAVPIER", WEATHER, "Activa lluvia."),
        Cheat("Tormenta", "EAKILHM", WEATHER, "Activa tormenta eléctrica."),
        Cheat("Niebla", "EGCEBVM", WEATHER, "Activa niebla densa."),
        Cheat("Tormenta de arena", "JBWDWWO", WEATHER, "Activa una tormenta de arena."),
        Cheat("Cielo naranja", "KTGDLXY", WEATHER, "Fija el reloj a las 21:00 y cambia el cielo."),
        Cheat("Siempre medianoche", "AWUJNBB", WEATHER, "Fija la hora a las 00:00."),
        Cheat("Reloj acelerado", "OWAKIJ", WEATHER, "Acelera el reloj del juego; repetir el código lo desactiva."),
        Cheat("Avanzar cuatro horas", "YACKMWS", WEATHER, "Avanza cuatro horas el reloj; código específico de la versión móvil."),
        Cheat("Puñetazo súper potente", "LRMYOJM", FUN, "Los golpes de CJ eliminan de un golpe.", "Los golpes de peatones también pueden ser letales si no tienes salud infinita."),
        Cheat("Súper salto", "BFMANNZP", FUN, "CJ salta mucho más alto."),
        Cheat("Modo adrenalina", "SLSNRKK", FUN, "Ralentiza la acción y aumenta la fuerza de CJ."),
        Cheat("Tema de playa", "BWCMMTD", FUN, "Cambia ropa, peatones y vehículos a un tema playero."),
        Cheat("Tema casa de diversión", "HDLIWGB", FUN, "Convierte el mundo en un carnaval.", "Puede fallar la misión Valet."),
        Cheat("Tema atrevido", "BNIZWSB", FUN, "Cambia peatones y vestuario al tema correspondiente.", "Puede fallar la misión Valet."),
        Cheat("Tema rural", "OAXCCRI", FUN, "Cambia peatones, tráfico y ropa a un tema rural.", "Puede fallar la misión Valet."),
        Cheat("Tema ninja", "AAUSQP", FUN, "CJ obtiene una katana y aparecen miembros del Triad."),
        Cheat("Elvis está en todas partes", "LNHVOAE", FUN, "Muchos peatones se convierten en imitadores de Elvis."),
        Cheat("Reclutar con pistolas", "JEZRPI", FUN, "Permite reclutar peatones que llevan pistolas."),
        Cheat("Reclutar con AK-47", "AWIOMPH", FUN, "Permite reclutar peatones que llevan AK-47."),
        Cheat("Reclutar con lanzacohetes", "QAONHOH", FUN, "Permite reclutar peatones que llevan lanzacohetes."),
        Cheat("Juego acelerado", "EHWBWDS", FUN, "Acelera la velocidad global del juego."),
        Cheat("Cámara lenta", "FNJFCZC", FUN, "Ralentiza la velocidad global del juego."),
        Cheat("Completar misión actual", "BYIXZIY", FUN, "Completa la misión actual; código específico de la edición móvil.")
    )

    fun search(query: String, category: String?): List<Cheat> {
        val normalized = query.trim().lowercase()
        return all.filter { cheat ->
            (category == null || cheat.category == category) &&
                (normalized.isEmpty() ||
                    cheat.title.lowercase().contains(normalized) ||
                    cheat.code.lowercase().contains(normalized) ||
                    cheat.description.lowercase().contains(normalized))
        }
    }
}
