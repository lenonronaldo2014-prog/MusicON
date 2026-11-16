package com.musicon.musicon

import java.util.Calendar
import java.util.GregorianCalendar
import java.util.TimeZone
import kotlin.random.Random

data class DailyWord(val category: String, val text: String, val reference: String = "")

/** Original reflections; biblical entries are paraphrases, with their source. */
object DailyWordContent {
    val words = listOf(
        DailyWord("Bíblica", "Mesmo nos dias difíceis, você pode encontrar descanso em Deus.", "Inspirada em Mateus 11:28"),
        DailyWord("Motivacional", "Um passo pequeno ainda é um passo. Respeite seu ritmo e continue."),
        DailyWord("Reflexão", "Você não precisa ter todas as respostas para viver este dia com cuidado."),
        DailyWord("Bíblica", "A esperança se renova a cada manhã. Hoje também pode ser um recomeço.", "Inspirada em Lamentações 3:22–23"),
        DailyWord("Motivacional", "O que você consegue fazer hoje já merece o seu reconhecimento."),
        DailyWord("Reflexão", "Escutar com atenção pode ser a forma mais simples de oferecer carinho."),
        DailyWord("Bíblica", "Há tempo de plantar e tempo de colher. Tenha paciência com o seu processo.", "Inspirada em Eclesiastes 3:1–2"),
        DailyWord("Motivacional", "Recomeçar não apaga seu caminho. É uma maneira de seguir em frente."),
        DailyWord("Reflexão", "Nem tudo precisa ser resolvido agora. Dê espaço para respirar."),
        DailyWord("Bíblica", "Que o amor apareça nas suas atitudes, até nas menores.", "Inspirada em 1 Coríntios 16:14"),
        DailyWord("Motivacional", "Descansar também faz parte de construir algo que vale a pena."),
        DailyWord("Reflexão", "Uma palavra gentil pode ficar com alguém por muito tempo."),
        DailyWord("Bíblica", "Você não precisa caminhar sem ajuda. Busque força e companhia.", "Inspirada em Isaías 41:10"),
        DailyWord("Motivacional", "Coragem pode ser apenas tentar mais uma vez, com mais gentileza consigo."),
        DailyWord("Reflexão", "Antes de se cobrar tanto, lembre de tudo o que você já atravessou."),
        DailyWord("Bíblica", "A paz pode encontrar espaço em um coração que entrega suas preocupações.", "Inspirada em Filipenses 4:6–7"),
        DailyWord("Motivacional", "Compare seu progresso com o seu próprio começo, respeitando a sua história."),
        DailyWord("Reflexão", "Estar presente vale mais do que encontrar a frase perfeita."),
        DailyWord("Bíblica", "Cuidar de quem está perto é uma forma de praticar o amor.", "Inspirada em Marcos 12:31"),
        DailyWord("Motivacional", "Seu valor não depende de um dia produtivo. Cuide de você também."),
        DailyWord("Reflexão", "O que merece sua atenção hoje? Às vezes, o essencial é bem simples."),
        DailyWord("Bíblica", "Mesmo em caminhos incertos, a fé pode iluminar o próximo passo.", "Inspirada em Salmos 119:105"),
        DailyWord("Motivacional", "Você pode aprender enquanto caminha. Não é preciso começar sabendo tudo."),
        DailyWord("Reflexão", "Pedir ajuda é abrir espaço para que o cuidado chegue até você."),
        DailyWord("Bíblica", "A mansidão também é força. Escolha responder com cuidado.", "Inspirada em Provérbios 15:1"),
        DailyWord("Motivacional", "Uma dificuldade de hoje não define todas as possibilidades de amanhã."),
        DailyWord("Reflexão", "Há beleza nas coisas discretas: um abraço, uma pausa, uma música."),
        DailyWord("Bíblica", "O bem que você faz com sinceridade pode florescer no tempo certo.", "Inspirada em Gálatas 6:9"),
        DailyWord("Motivacional", "Celebre o que avançou, mesmo quando ainda há muito pela frente."),
        DailyWord("Reflexão", "Você pode mudar de ideia quando aprende algo novo. Crescer também é isso."),
        DailyWord("Bíblica", "A fé, a esperança e o amor podem sustentar seus encontros de hoje.", "Inspirada em 1 Coríntios 13:13"),
        DailyWord("Motivacional", "Faça o possível com o que tem agora. O próximo passo pode surgir depois."),
        DailyWord("Reflexão", "Trate seus limites com o mesmo respeito que oferece a quem você ama."),
        DailyWord("Bíblica", "Um coração agradecido pode perceber cuidado nos detalhes do caminho.", "Inspirada em 1 Tessalonicenses 5:18"),
        DailyWord("Motivacional", "Hoje você pode escolher uma pequena atitude que faça bem ao seu futuro."),
        DailyWord("Reflexão", "Que sua pressa não esconda as pessoas que caminham ao seu lado."),
        DailyWord("Bíblica", "Partilhar a alegria e acolher a tristeza aproxima os corações.", "Inspirada em Romanos 12:15"),
        DailyWord("Motivacional", "Permita-se começar de um jeito simples. O começo não precisa ser perfeito."),
        DailyWord("Reflexão", "Uma conversa sincera pode abrir uma janela onde só parecia haver parede."),
        DailyWord("Bíblica", "A sabedoria também está em ouvir antes de falar.", "Inspirada em Tiago 1:19"),
        DailyWord("Motivacional", "Mude o plano quando precisar. Seus sonhos podem encontrar novos caminhos."),
        DailyWord("Reflexão", "Qual gentileza você pode oferecer a si mesmo nesta manhã?"),
        DailyWord("Bíblica", "A generosidade pode transformar o dia de quem recebe e de quem oferece.", "Inspirada em Provérbios 11:25"),
        DailyWord("Motivacional", "Reconheça sua caminhada. Há esforço seu até nas conquistas silenciosas."),
        DailyWord("Reflexão", "Nem todo silêncio é vazio. Alguns momentos só precisam de presença.")
    ) + DailyWordExtraContent.words

    fun dateKey(now: Long, zone: TimeZone = TimeZone.getDefault()): String {
        val day = Calendar.getInstance(zone).apply { timeInMillis = now }
        return "${day.get(Calendar.YEAR)}-${day.get(Calendar.MONTH) + 1}-${day.get(Calendar.DAY_OF_MONTH)}"
    }

    fun forDay(now: Long, seed: Int, zone: TimeZone = TimeZone.getDefault()): DailyWord {
        val local = Calendar.getInstance(zone).apply { timeInMillis = now }
        val day = GregorianCalendar(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(local.get(Calendar.YEAR), local.get(Calendar.MONTH), local.get(Calendar.DAY_OF_MONTH))
        }.timeInMillis / 86_400_000L
        // A stable shuffled cycle: no repeats until every message has appeared.
        val order = words.shuffled(Random(seed))
        return order[Math.floorMod(day, order.size.toLong()).toInt()]
    }

    fun nextMorning(now: Long, zone: TimeZone = TimeZone.getDefault()): Long =
        Calendar.getInstance(zone).apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, 8)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= now) add(Calendar.DAY_OF_MONTH, 1)
        }.timeInMillis
}
