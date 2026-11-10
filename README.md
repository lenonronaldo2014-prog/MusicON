# MusicON

Protótipo Android separado para testar busca no YouTube e reprodução de uma faixa por vez, inclusive em segundo plano. Mantém Flutter e conecta NewPipeExtractor v0.27.0 ao Android via MethodChannel. O pacote é `com.musicon.musicon.prototype`, nome **MusicON**; não substitui o MusicON principal nem acessa sua biblioteca.

## Visual

<img src="docs/images/inicio-verde.png" width="280" alt="Tela inicial do MusicON no tema verde"> <img src="docs/images/configuracoes.png" width="280" alt="Configurações de cores e atualizações">

## Usar

### Atualização visual 0.3.1

Identidade MusicON na tela de busca, capas/miniaturas nos resultados e no mini player, destaque da faixa atual e progresso com tempo em minutos e segundos. A imagem é a miniatura retornada pela fonte, não uma identificação garantida da capa oficial do álbum. Quando não há imagem ou ela falha, aparece uma capa ilustrada de reserva. A busca funciona pelo botão de seta no campo ou pela ação Buscar do teclado.

O OuterTune foi avaliado como referência, mas não foi integrado: sua versão com streaming também usa YouTube Music/InnerTube e depende do NewPipeExtractor, portanto não é uma fonte independente contra bloqueios. O repositório informa que não está em desenvolvimento ativo. Os 20 resultados por consulta são uma escolha deste protótipo, não uma cota diária do NewPipe.

Referências: [situação do OuterTune](https://github.com/OuterTune/OuterTune), [dependência do extrator](https://github.com/OuterTune/OuterTune/blob/dev/innertube/build.gradle.kts), [busca InnerTube](https://github.com/OuterTune/OuterTune/blob/dev/innertube/src/main/java/com/zionhuang/innertube/YouTube.kt).

Abra `MusicON-NewPipe.code-workspace` (na pasta acima) no VS Code e use a configuração **MusicON • NewPipe teste**, ou execute nesta pasta:

```powershell
flutter pub get
flutter run -t lib/main_newpipe.dart
```

Para gerar o APK de desenvolvimento:

```powershell
flutter build apk --release -t lib/main_newpipe.dart
```

Use Flutter 3.41.5 / Dart 3.11.3, Java do Android Studio e Android SDK. Android mínimo API 24. A primeira compilação baixa dependências Maven Central, Google e JitPack. `lib/main.dart` também encaminha para o aplicativo atual; `flutter run` abre a mesma versão.

No app, digite uma música/artista ou cole um link HTTPS de vídeo público do YouTube. Toque em um resultado para reproduzir. Pause e continue pelo app ou pelos controles de mídia Android. O protótipo retorna até 20 resultados por pesquisa e reproduz uma faixa por vez.

## Resultado observado

Teste real da base 0.3 em emulador Android:

- Compilação e instalação do APK: concluídas.
- Pesquisa `Blender Big Buck Bunny`: 20 resultados.
- Reprodução do vídeo público `aqz-KE-bpKQ`, da Blender Foundation: iniciada.
- Android confirmou `mWakefulness=Asleep` durante a reprodução.
- Posição passou de 3 para 28 segundos, com o player ainda em reprodução ao final.

O primeiro ensaio usando uma requisição HTTP comum retornou 403. A fonte de áudio foi adaptada ao transporte usado pelo NewPipe: POST, cabeçalhos fornecidos conforme o cliente e solicitações por faixa de bytes. O segundo ensaio passou. Isso confirma a viabilidade neste ambiente, não a disponibilidade universal do conteúdo ou estabilidade permanente.

Os 24 testes automatizados da base e do protótipo passaram antes do empacotamento. A análise estática é executada no projeto completo. Os testes Dart simulam o canal nativo; o ensaio acima usa rede, extrator e player reais no emulador. Ainda falta testar celular físico, redes diferentes, faixas diferentes e uso prolongado.

## Escopo e manutenção

Busca e reprodução de vídeo público, sem login ou cookies. Não inclui importação de playlists, paginação da busca, downloads de YouTube, integração com favoritos/biblioteca, nem garantia de reprodução de conteúdo restrito. A biblioteca da versão principal não foi alterada.

O endereço temporário de áudio é resolvido novamente a cada seleção e permanece apenas em memória. Para repetir um item após um erro, toque no resultado novamente. Alterações na fonte, bloqueios de rede e expiração dos endereços podem impedir a reprodução.

O adaptador utiliza `StreamAudioSource`, API experimental de `just_audio`, isolada neste protótipo e com versão fixada em 0.10.6. A comunicação externa usa HTTPS; HTTP é permitido somente no loopback para a ponte interna do player. Nunca desabilita verificação de certificados.

## Testar

```powershell
flutter analyze
flutter test
```

Existe um ensaio de rede optativo:

```powershell
flutter run -t lib/main_newpipe.dart --dart-define=NEWPIPE_PROBE=true
```

Somente em debug e com esse argumento o app pesquisa e reproduz automaticamente o filme público de teste. Ao emitir `MUSICON_PROBE ready_for_screen_off`, apague a tela e espere 25 segundos. O resultado fica no arquivo privado `app_flutter/newpipe-probe.json`. O APK entregue para uso manual é compilado **sem** esse argumento. A confirmação de tela apagada foi registrada separadamente via ADB no ensaio desta entrega.

## Arquivos principais

- `lib/main_newpipe.dart`: inicialização e ensaio optativo.
- `lib/newpipe_prototype.dart`: pesquisa, resultados, controle de erros e reprodução.
- `lib/newpipe_audio_source.dart`: transporte de áudio por POST/faixa de bytes.
- `lib/just_audio_engine.dart`: player com fábrica opcional para fontes online.
- `android/app/src/main/kotlin/com/musicon/musicon/NewPipeBridge.kt`: ponte nativa e acesso ao extrator em thread de trabalho.
- `test/newpipe_test.dart`: testes de pesquisa, URLs temporários, erros e tela.

## Licença e referências

Este protótipo combinado é disponibilizado sob **GPL-3.0-or-later**, conforme `LICENSE`. Bibliotecas de terceiros mantêm suas próprias licenças. A licença do software não concede direitos sobre músicas/vídeos nem autorização dos serviços. A integração é independente e não é patrocinada pelo YouTube ou pelo NewPipe.

- [NewPipeExtractor v0.27.0](https://github.com/TeamNewPipe/NewPipeExtractor/tree/v0.27.0)
- [NewPipe](https://github.com/TeamNewPipe/NewPipe)
- [Transporte de reprodução de referência](https://github.com/TeamNewPipe/NewPipe/blob/dev/app/src/main/java/org/schabi/newpipe/player/datasource/YoutubeHttpDataSource.java)
- [just_audio](https://pub.dev/packages/just_audio/versions/0.10.6)

O arquivo de fontes publicado pelo NewPipeExtractor acompanha a pasta `third_party`. As versões das dependências estão fixadas no Gradle e em `pubspec.lock`; compile pelos comandos acima. Este APK usa assinatura de desenvolvimento e não é uma entrega para loja.

## Publicar a próxima versão

1. Incremente a versão e o número de compilação no `pubspec.yaml` (ex.: `0.5.1+7`).
2. Execute `flutter analyze` e `flutter test`.
3. Gere `flutter build apk --release -t lib/main_newpipe.dart` usando a mesma chave de assinatura.
4. Copie o APK gerado para `MusicON.apk` e publique uma Release pública com tag `v0.5.1`, incluindo esse arquivo com o nome exato. Não marque como pré-lançamento se quiser que o botão de atualização a encontre.
5. Faça commit do código correspondente e aponte a tag para esse commit, para que os fontes da versão estejam disponíveis.

A consulta automática usa `GET /repos/lenonronaldo2014-prog/MusicON/releases/latest`, sem autenticação. Os limites públicos do GitHub e a conexão podem afetar a consulta; o usuário pode tentar novamente pelo botão.
