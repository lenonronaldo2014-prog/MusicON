# MusicON para Windows

Aplicativo para Windows 10/11 de 64 bits, com a identidade visual do MusicON, navegação lateral em janelas largas, busca online, músicas do computador, favoritos, playlists, downloads e temas.

## Instalação

Na [última versão](https://github.com/lenonronaldo2014-prog/MusicON/releases/latest), baixe **MusicON-Setup.exe** e execute. O instalador utiliza a pasta de programas do seu usuário e oferece atalhos. Atualize usando o mesmo instalador; as configurações e a biblioteca ficam fora da pasta do programa.

Alternativamente, baixe **MusicON-Windows-x64.zip**, extraia a pasta inteira e execute **MusicON.exe**. Preserve `data`, `support` e as DLLs junto do executável. O ZIP é uma distribuição sem instalação; os dados do usuário continuam sendo salvos no perfil do Windows, não dentro do ZIP.

O pacote já leva o player nativo e um runtime Java reduzido para a busca. Não exige instalar Java, Flutter, Android Studio ou um emulador.

## Músicas do computador

O MusicON consulta inicialmente a pasta `Music` dentro do perfil do Windows, quando ela existe. Use **+ > Adicionar pasta de músicas** para incluir outras pastas, inclusive uma pasta Música redirecionada para OneDrive ou outra unidade. As pastas escolhidas ficam salvas; mudanças nos arquivos atualizam a biblioteca. Também é possível escolher arquivos individualmente.

As faixas encontradas nas pastas não são copiadas. Ao excluir uma delas pelo MusicON, existe confirmação e a operação é enviada ao sistema de arquivos do Windows com opção de Lixeira. A disponibilidade de recuperação depende da unidade. O aplicativo restringe a operação às pastas de músicas configuradas e aos tipos de áudio suportados.

Downloads, cópias importadas pelo seletor, configurações e a biblioteca são armazenados no diretório de dados do aplicativo no perfil do usuário. Músicas das pastas originais continuam no local em que estavam. Instalar outra versão não remove esses dados. O desinstalador remove o programa e seus atalhos, preservando os dados do usuário.

## Busca, player e offline

Use o controle de volume na barra inferior durante a reprodução. Em uma janela estreita, clique no ícone de alto-falante para abrir o ajuste. O controle também aparece no player completo. O volume escolhido é lembrado e afeta apenas o MusicON.

A busca utiliza o mesmo NewPipeExtractor v0.27.0 do Android, executado em um processo auxiliar local que se comunica por canais privados de entrada/saída. Não cria um servidor de controle exposto na rede. A fonte recebe os termos pesquisados e os pedidos necessários para fornecer áudio e capas.

O player Windows usa just_audio com media_kit/libmpv. Ele permanece tocando ao minimizar a janela. Fechar o aplicativo encerra a reprodução. Favoritos, playlists, sequência, aleatório e o download completo para ouvir offline utilizam os mesmos controles da versão Android. Mantenha o MusicON aberto até o download terminar.

O endereço temporário de áudio é resolvido quando necessário e não é salvo na biblioteca. Disponibilidade da fonte e alterações do serviço ainda podem impedir uma busca ou reprodução.

## Spotify opcional

No Windows, a conexão é feita pelo navegador e retorna em **`http://127.0.0.1:8888/callback`**, endereço já cadastrado no projeto. O MusicON precisa continuar aberto durante a autorização. Depois de autorizar, volte à janela do programa. O estado e o código PKCE são validados; a sessão é cifrada com DPAPI, vinculada à conta do Windows.

A função transfere metadados de playlists autorizadas e permite escolher versões na busca do MusicON. Não reproduz nem baixa o áudio original do Spotify. Permanecem os limites e requisitos de acesso do cadastro Spotify, inclusive Premium na conta responsável em desenvolvimento e acesso às playlists permitido pela API.

## Compilação

Requisitos: Flutter 3.41.5, ferramentas C++ do Visual Studio para Windows, JDK 21 e Inno Setup 6. O workflow `.github/workflows/windows.yml` utiliza um runner Windows com essas ferramentas.

```powershell
./tool/build-windows.ps1
```

O script compila o extrator Java, prepara o runtime, gera o aplicativo Flutter, inclui o runtime C++ e produz `dist/MusicON-Setup.exe` e `dist/MusicON-Windows-x64.zip`. O código-fonte do extrator e os scripts de empacotamento estão neste repositório. Licenças e avisos acompanham a distribuição na pasta `support` e o runtime mantém seus avisos em `support/runtime/legal`.

O comando de teste de execução aceita `MusicON.exe --smoke-report=C:\caminho\relatorio.json`: exporta uma imagem da tela, verifica a busca e toca arquivos de teste local e online. Não adiciona esses arquivos à biblioteca nem autoriza uma conta Spotify.
