package com.musicon.musicon

/** Additional original messages. Biblical entries are identified paraphrases. */
object DailyWordExtraContent {
    private val biblicalText = """
Salmos 23:1|Deus conhece suas necessidades. Leve a Ele aquilo que pesa no seu coração.
Salmos 23:2–3|Até quem cuida de muita gente precisa de descanso. Permita que Deus renove suas forças.
Salmos 23:4|Em tempos de medo, a presença de Deus pode ser companhia no caminho.
Salmos 23:6|Reserve um momento para reconhecer os sinais de bondade que alcançaram sua vida.
Salmos 46:1|Quando tudo parece instável, você pode buscar em Deus abrigo para o coração.
Salmos 46:10|Faça uma pausa na agitação e abra espaço para estar com Deus.
Salmos 121:1–2|Ao procurar ajuda, lembre-se de que a fé também pode sustentar o seu olhar.
Salmos 121:3–4|Você pode descansar sem precisar vigiar cada detalhe da vida. Entregue suas preocupações a Deus.
Salmos 34:18|Um coração ferido também pode se aproximar de Deus. A dor não precisa esconder sua oração.
Salmos 34:8|Perceber a bondade de Deus pode começar pela atenção aos pequenos cuidados de hoje.
Salmos 37:5|Apresente seus caminhos a Deus e caminhe com responsabilidade, um dia de cada vez.
Salmos 37:7|Esperar com fé também pode ser uma forma de encontrar serenidade.
Salmos 56:3|Sentir medo não impede você de confiar. Conte a Deus o que está acontecendo por dentro.
Salmos 62:8|Sua oração pode ser sincera. Há espaço para abrir o coração diante de Deus.
Salmos 90:12|Peça sabedoria para viver o tempo de hoje com presença e propósito.
Salmos 100:2|Servir com alegria pode dar um novo sentido às pequenas tarefas do dia.
Salmos 103:2|Lembrar dos cuidados recebidos pode alimentar a gratidão no seu coração.
Salmos 139:14|Olhe para sua vida com respeito. Você merece cuidado e não precisa diminuir sua existência.
Salmos 145:18|Uma oração simples e verdadeira também pode aproximar você de Deus.
Salmos 147:3|Apresente suas feridas a Deus e permita-se receber cuidado durante o processo.
Provérbios 3:5–6|Nem tudo está ao alcance da sua compreensão. Peça direção a Deus para o próximo passo.
Provérbios 4:23|Cuide do que alimenta seu coração, porque isso também influencia seus caminhos.
Provérbios 12:25|Uma palavra de apoio pode aliviar um coração preocupado. Ofereça esse cuidado a alguém hoje.
Provérbios 16:9|Faça seus planos e mantenha o coração aberto à direção de Deus.
Provérbios 16:24|Palavras bondosas podem trazer alívio. Escolha com carinho o que você vai dizer.
Provérbios 17:17|A amizade pode ser presença constante, especialmente quando o dia fica difícil.
Provérbios 18:13|Antes de responder, dê ao outro a oportunidade de ser ouvido até o fim.
Provérbios 19:20|Aceitar um conselho sensato pode abrir espaço para crescer em sabedoria.
Provérbios 21:21|Procure agir com justiça e bondade nas decisões que este dia trouxer.
Provérbios 27:17|Uma amizade sincera pode ajudar você a amadurecer. Valorize quem caminha com honestidade ao seu lado.
Mateus 5:7|A misericórdia começa quando olhamos para a necessidade do outro com compaixão.
Mateus 5:9|Construir a paz pode começar por uma conversa conduzida com respeito.
Mateus 5:14–16|Deixe que suas boas atitudes levem um pouco de luz aos lugares por onde você passar.
Mateus 6:3–4|Há beleza em fazer o bem sem precisar transformar o gesto em reconhecimento.
Mateus 6:21|Observe onde você tem colocado sua atenção. Seu coração também acompanha suas escolhas.
Mateus 6:26|Quando a preocupação apertar, lembre-se do cuidado de Deus e busque o apoio de que precisa.
Mateus 6:34|Você pode cuidar das responsabilidades de hoje sem carregar todos os amanhãs de uma vez.
Mateus 7:7|Continue apresentando suas perguntas a Deus. A oração também é espaço de busca.
Mateus 7:12|Ofereça às pessoas o respeito e a consideração que você gostaria de receber.
Mateus 11:29|A mansidão de Jesus convida você a aprender um modo mais cuidadoso de caminhar.
Mateus 18:20|Orar em companhia pode fortalecer vínculos e renovar a fé de quem se reúne.
Mateus 22:39|O cuidado com o próximo pode começar pelas pessoas que cruzam seu dia comum.
Mateus 25:35–36|Um gesto concreto de acolhimento pode expressar a fé melhor do que muitas palavras.
Marcos 4:39|Leve suas tempestades interiores a Jesus e procure espaço para escutar com calma.
Marcos 9:24|Você pode apresentar a Deus tanto a sua fé quanto as suas dúvidas.
Marcos 10:14|Acolher as crianças com atenção e respeito também é uma forma de seguir o exemplo de Jesus.
Lucas 6:36|Exercitar a compaixão é lembrar que o outro também carrega uma história.
Lucas 6:45|Alimente seu coração com aquilo que ajuda suas palavras a produzir cuidado.
Lucas 10:33–34|A compaixão se torna concreta quando a gente se aproxima de quem precisa de ajuda.
Lucas 12:6–7|Sua vida tem valor diante de Deus, inclusive nos dias em que você custa a perceber isso.
Lucas 15:4–6|Nenhuma pessoa deve ser tratada como esquecível. O cuidado de Deus inspira a procurar quem ficou para trás.
Lucas 15:20|A imagem de um abraço que acolhe pode lembrar você da misericórdia de Deus.
Lucas 16:10|A fidelidade também aparece nos compromissos pequenos que assumimos a cada dia.
Lucas 22:42|Você pode falar com Deus sobre o que deseja e pedir força para atravessar o que é difícil.
João 4:14|Procure em Jesus aquilo que alimenta o coração para além das satisfações passageiras.
João 6:35|Sua vida espiritual também precisa de alimento. Separe um momento para cuidar dela hoje.
João 8:12|Peça a Jesus luz para reconhecer o próximo passo, mesmo quando o caminho inteiro ainda não está claro.
João 10:10|A fé pode convidar você a viver com mais presença, cuidado e sentido.
João 10:14|Ser conhecido e acolhido pode trazer descanso. Leve sua vida como ela está a Jesus.
João 13:34–35|Que o amor seja reconhecido na maneira como você trata as pessoas.
João 14:1|Quando o coração estiver inquieto, encontre na oração um lugar para apresentar suas preocupações.
João 14:27|Busque em Jesus uma paz que ajude você a enfrentar o dia sem negar o que sente.
João 15:5|Assim como os ramos precisam da videira, sua fé também pode ser nutrida pela proximidade com Jesus.
João 15:12|Amar pode exigir atenção, presença e disposição para cuidar de verdade.
João 16:33|As dificuldades fazem parte da vida. Em Cristo, você pode buscar coragem para atravessá-las.
Atos 20:35|Compartilhar o que você pode oferecer pode levar cuidado a quem está precisando.
Romanos 5:3–4|Em meio às dificuldades, peça a Deus perseverança e companhia para seguir.
Romanos 8:26|Quando faltarem palavras para orar, você ainda pode se apresentar a Deus em silêncio.
Romanos 8:38–39|A mensagem do amor de Deus pode ser abrigo quando você se sente distante ou sozinho.
Romanos 12:2|Reserve espaço para rever suas escolhas e cultivar uma maneira mais consciente de viver.
Romanos 12:9|Que sua bondade seja sincera e apareça no modo como você age.
Romanos 12:10|Demonstre consideração pelas pessoas sem esperar uma ocasião especial para isso.
Romanos 12:12|Alimente a esperança, persevere nas dificuldades e mantenha espaço para a oração.
Romanos 12:18|Faça o que estiver ao seu alcance para cultivar relações mais pacíficas.
Romanos 12:21|Não permita que uma atitude ruim decida o tamanho da sua bondade.
Romanos 15:13|Peça a Deus que renove a esperança e abra espaço para a alegria no seu dia.
1 Coríntios 3:6|Faça sua parte com cuidado e reconheça que nem todo crescimento está sob seu controle.
1 Coríntios 10:24|Ao fazer uma escolha, considere também o bem das pessoas ao seu redor.
1 Coríntios 12:26|A alegria e a dor do outro merecem acolhimento. Somos chamados a cuidar uns dos outros.
1 Coríntios 13:4|A paciência e a bondade ajudam o amor a se tornar visível nas relações.
1 Coríntios 13:7|Que o amor encontre em você disposição para permanecer presente nos dias trabalhosos.
1 Coríntios 15:58|Seu esforço para praticar o bem merece constância, mesmo quando o resultado ainda não aparece.
2 Coríntios 1:3–4|O acolhimento que você recebeu pode inspirar a maneira como conforta alguém hoje.
2 Coríntios 4:16|Peça a Deus renovação interior para atravessar os dias que exigem mais de você.
2 Coríntios 5:7|Há passos que pedem confiança mesmo quando ainda não conseguimos enxergar o resultado.
2 Coríntios 5:17|A vida com Cristo convida a novos começos e a uma forma renovada de caminhar.
2 Coríntios 9:7|A generosidade pode nascer de uma escolha livre e de um coração disposto a partilhar.
2 Coríntios 12:9|Reconhecer sua fragilidade pode abrir espaço para experimentar a graça de Deus.
Gálatas 5:13|Use sua liberdade para oferecer cuidado e servir com amor.
Gálatas 5:22–23|Cultive paciência, bondade e domínio próprio nas situações comuns deste dia.
Gálatas 6:2|Você não precisa resolver a dor do outro para ajudar a carregar um pouco do peso.
Gálatas 6:10|A oportunidade de fazer o bem pode estar em uma situação simples bem perto de você.
Efésios 2:10|Procure hoje uma oportunidade concreta de colocar sua fé em uma boa atitude.
Efésios 4:2|Humildade, paciência e mansidão podem mudar a maneira como uma conversa acontece.
Efésios 4:29|Antes de falar, pense em como suas palavras podem ajudar quem vai ouvi-las.
Efésios 4:32|Trate o outro com bondade e compaixão, lembrando também da graça que recebeu.
Efésios 5:15–16|Dê atenção ao modo como vive seu tempo. Há escolhas pequenas que merecem cuidado.
Efésios 6:18|A oração pode acompanhar tanto os grandes desafios quanto as tarefas mais comuns.
Filipenses 1:6|Confie a Deus seu processo de amadurecimento e continue cuidando do próximo passo.
Filipenses 2:3–4|Escute também as necessidades do outro quando decidir como agir.
Filipenses 2:14|Busque uma forma construtiva de lidar com o que precisa ser feito hoje.
Filipenses 4:5|Que sua gentileza seja percebida por quem encontra você no caminho.
Filipenses 4:8|Dê espaço aos pensamentos que aproximam você da verdade, da justiça e da bondade.
Filipenses 4:11–12|Encontrar contentamento pode ser um aprendizado que atravessa diferentes fases da vida.
Filipenses 4:13|Busque em Cristo força para permanecer firme nas diferentes circunstâncias da vida.
Colossenses 3:12|Vista suas atitudes de compaixão, humildade, mansidão e paciência.
Colossenses 3:14|Ao cuidar das suas relações, deixe que o amor dê sentido às suas atitudes.
Colossenses 3:15|Abra espaço para a paz de Cristo orientar seu coração e suas relações.
Colossenses 3:16|Uma canção de gratidão também pode ser uma maneira de alimentar a fé.
Colossenses 3:23|Coloque cuidado no que faz, mesmo quando a tarefa parece pequena ou pouco visível.
Colossenses 4:6|Que suas palavras unam gentileza e atenção à história de quem conversa com você.
1 Tessalonicenses 5:11|Uma palavra de encorajamento pode ajudar alguém a se sentir acompanhado hoje.
1 Tessalonicenses 5:14|Tenha paciência com as pessoas e ofereça apoio a quem está mais frágil.
1 Tessalonicenses 5:15|Procure uma resposta que faça o bem, mesmo quando o dia trouxer contrariedade.
1 Tessalonicenses 5:17|Sua conversa com Deus pode continuar ao longo do dia, com palavras simples.
2 Tessalonicenses 3:13|Continue escolhendo o bem, cuidando também das forças de que você precisa para seguir.
2 Timóteo 1:7|Peça a Deus coragem, amor e equilíbrio para as decisões que estão diante de você.
2 Timóteo 4:7|A perseverança pode ser construída nas escolhas fiéis de cada dia.
Hebreus 4:16|Você pode se aproximar de Deus para pedir graça e ajuda nas suas necessidades.
Hebreus 6:19|Quando os pensamentos estiverem agitados, a esperança pode ser uma âncora para a sua fé.
Hebreus 10:24|Encorajar alguém a amar e fazer o bem também é um modo de cuidar.
Hebreus 10:25|A convivência e o encorajamento mútuo podem fortalecer sua caminhada de fé.
Hebreus 11:1|A fé abre espaço para confiar mesmo enquanto algumas respostas ainda não chegaram.
Hebreus 12:1|Identifique o que pesa desnecessariamente e peça perseverança para continuar seu caminho.
Hebreus 13:2|O acolhimento de uma pessoa pode transformar um encontro comum em cuidado.
Hebreus 13:16|Partilhar e praticar o bem são maneiras concretas de viver a fé.
Tiago 1:5|Quando faltar clareza, peça sabedoria a Deus e esteja disposto a aprender.
Tiago 1:17|Reconheça com gratidão as coisas boas que chegaram até você.
Tiago 1:22|Uma palavra de fé ganha vida quando se transforma em atitude.
Tiago 2:15–17|A fé também pode aparecer no alimento, no abrigo e na ajuda que oferecemos.
Tiago 3:17|A sabedoria pode ser reconhecida pela paz, pela gentileza e pela disposição de ouvir.
Tiago 4:8|Separe um instante do dia para se aproximar de Deus com sinceridade.
1 Pedro 4:8|Cuide dos seus vínculos com um amor atento, que não desiste de tratar o outro com dignidade.
1 Pedro 4:10|O que você sabe fazer pode se tornar uma forma de servir alguém.
1 Pedro 5:7|Você pode apresentar suas ansiedades a Deus e permitir-se receber ajuda.
1 João 3:18|Que o amor saia das palavras e encontre lugar nos seus gestos de hoje.
1 João 4:7|Cada gesto sincero de amor pode lembrar a presença de Deus nas nossas relações.
Isaías 40:31|Esperar em Deus pode renovar o fôlego de quem precisa continuar caminhando.
Miqueias 6:8|Pratique a justiça, cultive a misericórdia e caminhe com humildade diante de Deus.
Números 6:24–26|Que a bênção e a paz de Deus acompanhem sua caminhada neste dia.
    """.trimIndent()

    private val motivationalText = """
Você pode começar pelo que está ao seu alcance e deixar o restante para o próximo passo.
Um dia difícil não apaga as habilidades que você construiu ao longo do caminho.
Quando a tarefa parecer grande, escolha uma parte pequena e dê atenção a ela.
Sua constância pode ser discreta e ainda assim produzir mudanças importantes.
Você tem permissão para aprender devagar e fazer perguntas durante o processo.
Reconhecer que algo está difícil é uma maneira honesta de começar a lidar com isso.
Uma pausa pode ajudar você a voltar com mais clareza para o que importa.
Não é preciso esperar se sentir completamente pronto para dar um primeiro passo possível.
Cada tentativa pode ensinar algo, inclusive sobre o momento de mudar a estratégia.
Seu caminho pode ter desvios e ainda levar a descobertas que valem a pena.
Escolha uma tarefa de cada vez. Sua atenção merece um lugar para pousar.
O progresso de hoje pode ser organizar o que você precisa para começar amanhã.
Você pode ser firme nos seus objetivos e gentil com seu próprio tempo.
Aprender a dizer que precisa de ajuda também pode ser uma conquista.
Voltar ao que faz bem pode começar com uma decisão simples nesta manhã.
Uma dificuldade pede cuidado e estratégia, não uma sentença sobre quem você é.
Há habilidades que crescem com a prática, mesmo quando o começo parece desajeitado.
Você pode reconhecer seus erros sem transformar a conversa consigo em castigo.
Seu esforço merece respeito, mesmo quando os resultados demoram a aparecer.
Transforme uma intenção em um gesto possível. É assim que muitos começos acontecem.
Uma meta menor pode ajudar você a recuperar o movimento sem se sobrecarregar.
Você pode retomar um projeto com o conhecimento que ganhou durante a pausa.
Se hoje o ritmo precisar diminuir, procure manter o cuidado com o que é essencial.
Uma conversa com alguém experiente pode abrir uma alternativa que você ainda não enxergou.
Mudar de direção depois de refletir pode ser uma escolha corajosa.
Sua história contém aprendizados que podem ajudar no desafio que está diante de você.
Não despreze uma solução simples só porque ela não parece impressionante.
O hábito que você deseja cultivar pode começar com poucos minutos de atenção.
Você pode fazer algo bem feito sem exigir de si um resultado perfeito.
Uma escolha consciente hoje já é uma forma de participar do seu futuro.
Dar nome ao que você precisa pode tornar mais fácil buscar apoio.
O caminho de alguém não precisa servir de medida para o seu próprio percurso.
Você pode construir confiança lembrando das situações que já aprendeu a enfrentar.
O que ainda falta aprender não diminui o que você já sabe fazer.
Uma mudança sustentável também precisa caber na vida que você tem agora.
Permita que a curiosidade acompanhe o esforço. Aprender também pode trazer alegria.
Há dias em que continuar significa proteger suas forças para o que vem depois.
Você pode negociar prazos, rever prioridades e procurar uma forma mais possível de seguir.
Seu próximo passo pode ser fazer a pergunta que você vinha guardando.
Observe uma melhoria pequena e deixe que ela ajude você a reconhecer o caminho percorrido.
Uma tarefa concluída com atenção merece ser reconhecida, mesmo que ninguém tenha visto.
Você pode treinar uma habilidade sem exigir que cada prática vire uma prova de valor.
Trocar a cobrança por uma orientação concreta pode tornar o dia mais leve.
Se o plano ficou pesado demais, procure uma versão que você consiga sustentar.
Seu começo não precisa ter a aparência do resultado de quem já pratica há anos.
Há espaço para tentar de novo com outra ferramenta, outra ajuda ou outro ritmo.
Escolha uma prioridade que faça sentido para hoje e permita-se concentrar nela.
Você não precisa resolver uma fase inteira da vida nesta manhã.
Organizar o ambiente pode ser um primeiro gesto de apoio ao seu próprio esforço.
Um limite bem colocado pode proteger a energia necessária para algo importante.
Seu corpo faz parte da sua caminhada. Escute a necessidade de água, alimento e descanso.
Você pode reconhecer uma conquista antes de correr para a próxima obrigação.
Aprender com alguém não diminui sua capacidade; amplia seus recursos.
Uma tentativa honesta pode valer mais para o aprendizado do que uma espera interminável.
Você pode tornar um objetivo mais claro escrevendo o próximo passo que ele pede.
O ritmo de uma fase não precisa ser o ritmo de toda a sua vida.
Seu trabalho pode melhorar com ajustes pequenos feitos com atenção.
Você pode se orgulhar da coragem de ter começado algo que antes parecia distante.
Uma resposta negativa pode pedir uma nova rota, sem definir todas as suas possibilidades.
Escolha um compromisso possível consigo e procure honrá-lo com cuidado.
Você pode buscar excelência sem tratar suas necessidades como obstáculos.
O que funciona para você pode ser diferente do que funciona para quem está ao lado.
Separar o urgente do importante pode abrir espaço para respirar e agir melhor.
Há força em admitir que um caminho deixou de fazer sentido.
Você pode ajustar a meta quando sua realidade muda. Planejar também é escutar a vida.
Uma ideia merece ser explorada antes de você decidir que não é capaz de colocá-la em prática.
Suas habilidades podem encontrar novas formas de servir a algo que importa para você.
O primeiro rascunho é um espaço de descoberta. Dê a ele a liberdade de ser um começo.
Você pode aprender a lidar com uma situação sem precisar gostar dela.
Uma rotina mais simples pode liberar energia para aquilo que você quer cuidar melhor.
Reconheça o esforço de atravessar esta fase, mesmo que ainda não haja uma conquista para mostrar.
Você pode escolher uma atitude que torne o restante do seu dia um pouco mais possível.
Tornar a tarefa clara pode ajudar mais do que repetir para si que precisa dar conta.
Sua disposição pode variar. Procure um plano que também respeite os dias de menos energia.
Você pode transformar uma experiência difícil em aprendizado sem chamar a dor de necessária.
Reserve espaço para aquilo que desperta seu interesse. A curiosidade também merece tempo.
Uma boa parceria pode tornar mais leve um desafio que parecia solitário.
Você pode oferecer seu melhor de hoje sem exigir as forças que tinha em outra fase.
O caminho também se constrói quando você reconhece o que não quer repetir.
Experimentar uma abordagem diferente pode revelar uma capacidade que estava sem espaço.
Você pode seguir um objetivo por etapas e comemorar cada trecho concluído.
Aprender a descansar antes do esgotamento é uma habilidade que vale cultivar.
Sua atenção é valiosa. Procure entregá-la a uma coisa de cada vez quando puder.
Um obstáculo pode ser examinado por partes, com calma e com ajuda.
Você pode encerrar uma etapa com gratidão e abrir outra sem precisar prever tudo.
O esforço de hoje pode preparar uma possibilidade que ainda está tomando forma.
Busque uma referência que ensine e encoraje, em vez de aumentar sua cobrança.
Você pode construir um jeito de trabalhar que tenha espaço para cuidado e para resultados.
Fazer uma pergunta simples pode poupar horas de confusão. Sua dúvida merece ser ouvida.
Você tem o direito de começar uma nova atividade sem já ser bom nela.
Uma decisão pensada com calma pode ser mais útil do que uma resposta tomada na pressa.
Você pode revisar um compromisso quando percebe que assumiu mais do que consegue sustentar.
Seu aprendizado continua mesmo quando é preciso voltar a um assunto que parecia resolvido.
Escolher uma pequena melhoria é uma forma concreta de sair da ideia para a prática.
Você pode dar valor ao que faz sem depender o tempo todo da aprovação de alguém.
O resultado de uma tentativa é uma informação. Use-o para orientar seu próximo passo.
Há conquistas que acontecem quando você aprende a se proteger melhor.
Você pode reconhecer uma oportunidade e também avaliar se este é o momento de aceitá-la.
Persistir com consciência inclui perceber quando é hora de pedir apoio ou mudar o plano.
Uma agenda com espaço para imprevistos pode ajudar você a seguir com mais equilíbrio.
Você pode criar um começo acolhedor para uma tarefa que vinha adiando.
Seu compromisso consigo pode incluir tanto avançar quanto recuperar as forças.
Escrever o que já foi feito pode ajudar a enxergar um progresso que a pressa escondeu.
Você pode praticar coragem em uma conversa, em uma escolha ou em um pedido de ajuda.
Uma habilidade esquecida pode ser retomada com paciência e prática.
Você pode voltar a sonhar sem precisar transformar todo sonho em obrigação.
Uma melhoria no seu dia pode começar por retirar algo que estava pesando demais.
O que parece pequeno para outra pessoa pode representar um grande passo na sua história.
Você pode estabelecer uma meta e continuar aberto a aprender durante o percurso.
Reconhecer suas condições reais ajuda a construir planos que cuidam melhor de você.
Um pouco de preparação pode tornar o próximo passo menos assustador.
Você pode usar o que aprendeu ontem para fazer uma escolha mais consciente hoje.
O tempo dedicado a compreender uma tarefa também faz parte de realizá-la.
Você pode respeitar suas emoções e ainda escolher com cuidado o que fazer em seguida.
Há valor em manter um compromisso simples durante uma fase exigente.
Uma parceria respeitosa permite dividir responsabilidades sem diminuir a contribuição de ninguém.
Você pode reconhecer o que fez bem antes de analisar o que deseja melhorar.
Seu objetivo pode ganhar força quando você lembra por que ele importa para sua vida.
Uma pequena organização no presente pode tornar mais tranquilo o seu próximo começo.
Você pode experimentar algo novo sem abandonar o respeito pelos seus limites.
Construir autonomia também inclui saber a quem recorrer quando for preciso.
Você pode cuidar de um projeto sem deixar de cuidar de quem está realizando esse projeto: você.
Um dia de pouco avanço pode trazer uma informação importante sobre o que precisa mudar.
Você pode substituir uma meta vaga por uma ação que caiba na próxima hora.
Há aprendizados que aparecem ao compartilhar uma dificuldade com alguém de confiança.
Você pode praticar a mesma habilidade várias vezes sem chamar isso de fracasso.
Uma pausa consciente pode evitar que a pressa decida por você.
Você pode deixar algo mais simples e ainda preservar o que realmente importa.
O seu esforço pode ter valor mesmo quando precisa de ajustes para produzir o resultado desejado.
Você pode construir uma rotina que apoie seus planos em vez de exigir força o tempo todo.
Uma mudança de hábito pode começar pela compreensão do que torna esse hábito difícil.
Você pode guardar energia para uma prioridade sem se culpar por não abraçar todas as outras.
O próximo passo pode ser pequeno o bastante para começar e importante o bastante para contar.
Você pode aceitar um elogio sem precisar diminuir imediatamente o que realizou.
Há coragem em oferecer uma ideia mesmo sabendo que ela ainda pode ser melhorada.
Você pode escolher uma forma de seguir que também permita apreciar o caminho.
Uma tentativa feita com mais informação já pode ser diferente da anterior.
Você pode construir algo consistente ao repetir cuidados simples ao longo do tempo.
Reconhecer o próprio limite pode ser o começo de uma estratégia mais inteligente.
Você pode levar seus planos a sério sem perder a delicadeza na maneira de tratar a si mesmo.
    """.trimIndent()

    private val reflectionText = """
O que você tem chamado de falta de tempo talvez mereça uma conversa sobre prioridades.
Há encontros breves que deixam um cuidado duradouro. Preste atenção a quem passa pelo seu dia.
Você consegue lembrar de uma coisa simples que tornou sua manhã mais acolhedora?
Nem toda opinião precisa de uma resposta imediata. Você pode escolher o momento de conversar.
Às vezes, entender uma pessoa começa por suspender a vontade de corrigir o que ela sente.
O jeito como você fala consigo também faz parte do ambiente em que vive.
Uma pergunta feita com interesse pode aproximar mais do que uma resposta pronta.
Há lembranças que merecem carinho, mesmo quando a vida já seguiu por outros caminhos.
O que você gostaria de perceber melhor se diminuísse um pouco a pressa hoje?
Ter razão sobre um detalhe não resolve sozinho a necessidade de cuidar de uma relação.
Algumas coisas perdem força quando deixam de ser enfrentadas em segredo.
Uma casa pode se tornar mais acolhedora pelos gestos que acontecem dentro dela.
Você não conhece toda a história de quem encontrou hoje. Deixe espaço para a gentileza.
Qual parte do seu dia tem recebido menos cuidado do que precisa?
Uma lembrança boa pode ser visitada sem que o presente precise ser igual ao passado.
Há perguntas que amadurecem antes de encontrar uma resposta.
Escutar de verdade inclui permitir que a história do outro não se pareça com a sua.
Um limite explicado com respeito também pode ser uma forma de preservar um vínculo.
O que faz você se sentir acolhido pode ajudar a perceber como acolher alguém.
Nem toda mudança importante faz barulho. Algumas começam em uma escolha silenciosa.
Você pode sentir saudade de uma fase e ainda reconhecer que precisava seguir adiante.
O valor de um encontro nem sempre pode ser medido pelo tempo que ele durou.
Qual conversa você poderia tornar mais gentil escolhendo melhor o momento de falar?
Uma relação precisa de espaço para que as pessoas possam mudar sem deixar de ser ouvidas.
Às vezes, dizer que não sabe é o começo mais honesto de uma conversa.
O cuidado que chega de forma diferente da esperada ainda pode merecer reconhecimento.
Há beleza em perceber algo que sempre esteve ali e que a rotina tinha escondido.
Você tem permitido que os momentos bons terminem sem já correr para a próxima preocupação?
Uma pessoa pode precisar de presença antes de precisar de conselho.
O que você está tentando provar talvez já não corresponda ao que deseja viver.
Uma mesa compartilhada pode guardar mais do que alimento: pode guardar tempo oferecido.
Nem todo pensamento pede uma decisão. Alguns precisam primeiro ser compreendidos.
Qual hábito do seu dia expressa algo que você considera importante?
O silêncio pode acolher quando existe respeito, mas também merece conversa quando machuca.
Você pode reconhecer que alguém ajudou sem transformar isso em uma dívida sem fim.
Há formas de demonstrar amor que começam por respeitar uma escolha diferente da sua.
Uma desculpa sincera pode abrir uma porta, mas a confiança também precisa de atitudes depois dela.
O que você gostaria de agradecer a alguém enquanto ainda há oportunidade de dizer?
Uma música pode guardar uma lembrança e, em outro dia, ganhar um significado novo.
Você pode deixar uma história no passado sem precisar dizer que ela não teve importância.
Prestar atenção em como alguém recebe seu cuidado também é parte de cuidar.
Há momentos em que o melhor presente que você oferece é não estar com pressa.
Que parte da sua rotina ajuda você a se reconhecer no meio de tantas demandas?
Você pode admirar uma pessoa sem precisar reproduzir o modo como ela vive.
Uma conversa difícil costuma precisar de clareza, mas também de espaço para ouvir.
O que você evita sentir talvez esteja pedindo um acolhimento que a cobrança não consegue dar.
Há decisões que ficam mais claras quando você se pergunta o que deseja preservar.
Um gesto de respeito pode mudar o tom de um lugar, mesmo sem chamar atenção.
Você tem espaço no seu dia para alguma coisa que não precise produzir um resultado?
Não conhecer o destino inteiro não impede você de observar por onde está caminhando.
Uma diferença de ritmo não precisa significar falta de interesse. Às vezes, merece uma conversa.
O que você deseja manter na sua vida talvez precise de tempo reservado, não apenas de intenção.
Lembrar de alguém e avisar essa pessoa pode transformar uma lembrança em proximidade.
Há afeto em aprender como pronunciar um nome, lembrar uma preferência e escutar uma história.
Você pode encontrar satisfação em uma coisa comum sem precisar torná-la extraordinária.
Que lembrança você está ajudando a construir nas pessoas com quem convive hoje?
Alguns vínculos se fortalecem quando a gente deixa de presumir e começa a perguntar.
Você pode discordar de uma ideia e continuar tratando com dignidade quem a expressou.
O tempo de uma caminhada pode revelar detalhes que a velocidade de uma passagem esconde.
Uma escolha pode ser boa para esta fase sem precisar valer para todas as outras.
Você tem oferecido aos outros uma paciência que também poderia oferecer a si?
Há coisas que você só percebe quando para de usar a experiência de alguém como comparação.
Uma notícia boa merece espaço para ser sentida, mesmo em um dia cheio de obrigações.
O que você considera uma vida bem vivida aparece nas suas escolhas mais comuns?
Nem sempre aproximar é falar mais. Às vezes, é perguntar com mais atenção.
Uma amizade pode atravessar fases diferentes quando existe disposição para se reencontrar.
Você pode acolher um sentimento sem deixar que ele decida sozinho todos os seus passos.
Há detalhes que tornam um dia seu: um jeito de preparar o café, uma música, uma janela aberta.
Qual necessidade fica escondida quando você responde que está tudo bem por costume?
O cuidado com um lugar também aparece no modo como você o deixa para quem vem depois.
Você pode mudar uma expectativa depois de escutar com atenção a realidade de alguém.
Há memórias felizes feitas de dias que pareciam comuns enquanto aconteciam.
Que pequena presença da natureza você consegue perceber no seu caminho hoje?
Uma relação pode precisar menos de adivinhação e mais de pedidos claros.
Você pode se sentir grato por uma ajuda e ainda reconhecer que outras necessidades continuam.
O que você escolhe não alimentar também influencia o clima dos seus dias.
Uma palavra pode ser verdadeira e ainda precisar de cuidado na forma de ser dita.
Há aprendizados que chegam quando você pergunta como foi a experiência de outra pessoa.
Você tem escutado uma resposta inteira ou já está preparando o que vai dizer em seguida?
Um objeto simples pode carregar uma história que ninguém percebe olhando de fora.
O carinho pode aparecer na constância de um cuidado que quase nunca recebe destaque.
Você pode descobrir uma preferência nova ao se permitir experimentar sem obrigação de gostar.
Qual parte do seu dia você gostaria de viver com um pouco mais de presença?
Uma história contada por outra geração pode ampliar o modo como você entende a sua.
Há respeito em admitir que você não pode decidir pelo outro o que ele deveria sentir.
Você pode escolher palavras mais precisas quando deixa a pressa passar antes de responder.
O que parece óbvio para você pode ser uma descoberta para alguém. Explique com paciência.
Alguns dias pedem planos; outros pedem primeiro entender por que tudo ficou tão pesado.
Você consegue perceber quem costuma tornar sua rotina mais leve sem receber agradecimento?
Uma conversa pode ganhar profundidade quando ninguém precisa vencer para ser ouvido.
Estar perto de alguém inclui reconhecer que a pessoa tem um mundo que você ainda não conhece.
Que compromisso você assumiu por escolha e qual está mantendo apenas por medo de desagradar?
Há cuidado em oferecer ajuda e também em perguntar se aquela ajuda é desejada.
Você pode gostar do que tem e continuar desejando mudanças que façam sentido.
Uma leitura, uma música ou um encontro pode despertar uma pergunta que merece companhia.
O que você procura fora talvez também precise de um espaço mais atento dentro da sua rotina.
Há gentileza em não usar a vulnerabilidade de alguém como argumento numa discussão.
Você pode reconhecer a intenção de uma pessoa e conversar sobre o efeito que a atitude teve.
Qual gesto de acolhimento você recebeu e gostaria de passar adiante do seu próprio jeito?
O tempo livre também é tempo de vida. Ele merece existir sem precisar de uma justificativa constante.
Uma mudança no tom de voz pode tornar possível uma conversa que estava ficando difícil.
Você não precisa conhecer uma dor parecida para tratar a dor de alguém com respeito.
Há vínculos que se renovam quando as pessoas voltam a fazer perguntas umas às outras.
O que você costuma notar primeiro em um dia: o que faltou ou o que esteve presente?
Uma casa arrumada ajuda em algumas coisas; uma presença acolhedora ajuda em outras.
Você pode sentir alegria por alguém sem transformar a conquista dessa pessoa em cobrança para si.
Qual escolha de hoje pode tornar mais cuidadosa a sua convivência com alguém?
Há histórias que você conta sobre si que talvez mereçam ser revistas com mais gentileza.
Uma lembrança não precisa ser perfeita para ser preciosa.
Você pode respeitar uma tradição e também pensar em como deseja vivê-la nesta fase.
O jeito como você recebe uma dúvida pode influenciar a coragem de alguém de continuar aprendendo.
Há um tipo de atenção que diz, sem palavras, que a presença de alguém importa.
Qual preocupação você conseguiria explicar melhor se tivesse tempo para organizar o que sente?
Uma escolha feita por medo pode merecer outra conversa quando você se sentir mais seguro.
Você pode estar disponível para alguém sem prometer mais do que consegue oferecer.
Há beleza em acompanhar uma pessoa crescendo sem exigir que ela continue igual.
O que torna um lugar especial pode ser a maneira como você foi recebido ali.
Uma resposta cuidadosa pode incluir o pedido de um tempo para pensar.
Você tem reconhecido as pessoas pelo que são ou apenas pelo que costumam fazer por você?
Há momentos em que compartilhar uma alegria é uma forma de convidar alguém para perto.
Uma preferência diferente pode ser uma oportunidade de conhecer melhor a pessoa ao seu lado.
Você pode escolher o que contar sobre sua vida sem dever uma explicação completa a todo mundo.
Qual parte do seu dia teria outro significado se fosse vivida sem o celular por alguns minutos?
Uma palavra de reconhecimento pode dar nome a um cuidado que vinha passando despercebido.
Há decisões que pedem menos urgência e mais informação.
Você pode se aproximar de alguém com uma pergunta simples, sem precisar de um assunto perfeito.
O que você faz quando ninguém está avaliando também revela aquilo que considera importante.
Uma conversa sobre limites pode prevenir ressentimentos que o silêncio deixaria crescer.
Há carinho em lembrar que o outro não tem como adivinhar tudo o que você precisa.
Você pode revisitar um sonho antigo e perceber que ele mudou junto com você.
Qual experiência comum você gostaria de aproveitar antes de considerá-la apenas uma lembrança?
Uma forma de respeitar o tempo de alguém é estar presente no encontro que vocês escolheram ter.
Há situações em que a dúvida é mais honesta do que uma certeza apressada.
Você pode aprender algo sobre si ao perceber o que traz tranquilidade ao seu cotidiano.
O cuidado não precisa ter o mesmo formato em todos os dias para continuar sendo cuidado.
Qual assunto merece uma conversa verdadeira em vez de mais uma suposição?
Uma relação também se constrói na capacidade de reconhecer quando é preciso reparar um gesto.
Há pequenos rituais que ajudam a marcar a passagem de um dia para outro com mais calma.
Você pode dar valor a uma fase enquanto ela acontece, mesmo sem saber o que virá depois.
O que você deseja oferecer ao mundo pode começar no modo como trata a próxima pessoa que encontrar.
    """.trimIndent()

    val words: List<DailyWord> = buildList {
        biblicalText.lineSequence().filter { it.isNotBlank() }.forEach { line ->
            val (reference, text) = line.split('|', limit = 2)
            add(DailyWord("Bíblica", text, "Inspirada em $reference"))
        }
        motivationalText.lineSequence().filter { it.isNotBlank() }.forEach {
            add(DailyWord("Motivacional", it))
        }
        reflectionText.lineSequence().filter { it.isNotBlank() }.forEach {
            add(DailyWord("Reflexão", it))
        }
    }
}
