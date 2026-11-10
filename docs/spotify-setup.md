# Conectar o MusicON ao Spotify

O login é opcional. O aplicativo lê metadados das playlists autorizadas pela conta; não recebe arquivos de áudio do Spotify nem baixa músicas do Spotify. O usuário escolhe versões encontradas na busca do MusicON antes de importar uma coleção. Downloads offline usam a fonte da faixa escolhida no MusicON.

## Situação desta entrega

O código de login, armazenamento seguro da sessão, paginação e importação está implementado e coberto por testes. A autenticação real não foi validada porque ainda falta o cadastro do aplicativo e um Client ID. Sem configuração, a tela informa que a conexão está em preparação e não simula login ou playlists.

## Cadastro necessário

1. Entre no [Spotify for Developers](https://developer.spotify.com/dashboard) com a conta responsável pelo aplicativo.
2. Cadastre o MusicON com a Web API.
3. Cadastre o redirecionamento **`http://127.0.0.1/callback`**. O app escolhe uma porta livre no aparelho; o Spotify permite porta dinâmica para loopback explícito. Não use `localhost`.
4. Informe a política de privacidade pública: `https://github.com/lenonronaldo2014-prog/MusicON/blob/main/docs/privacy.md`.
5. Envie ao responsável pela compilação somente o **Client ID público**. Não envie Client Secret, senha nem tokens.
6. Em Users Management, adicione as contas de teste permitidas.

No modo de desenvolvimento atual, o responsável pelo cadastro precisa de Spotify Premium e há limite de cinco contas autenticadas na lista de autorizados. Playlists de terceiros podem fornecer apenas metadados, sem o conteúdo; a importação depende do acesso que a API concede à conta. Não há tentativa de contornar essa restrição.

## Compilar com o cadastro

```powershell
flutter build apk --release -t lib/main_newpipe.dart --dart-define=SPOTIFY_CLIENT_ID=SEU_CLIENT_ID_PUBLICO
```

Incremente versão e build antes de publicar uma atualização. Preserve a assinatura usada nas entregas anteriores.

O Client ID é um identificador público, não um segredo. O fluxo é Authorization Code com PKCE S256: o navegador trata o login e o aplicativo valida `state` no retorno. Não há Client Secret no APK. Os tokens são cifrados com AES-GCM usando uma chave no Android Keystore; o app permite desconectar e apagar a sessão. O botão de login precisa de um navegador instalado.

## Importação

Biblioteca > Importar do Spotify, ou Configurações > Spotify. Depois da conexão, escolha uma playlist ou use o link dela. Toque em cada faixa para escolher uma versão encontrada no MusicON. Só as seleções confirmadas são salvas, na ordem original. A importação pode ser parcial, e resultados podem ser versões diferentes da gravação do Spotify; a escolha é do usuário. Depois, use o download na playlist do MusicON se quiser disponibilizá-la offline.

Referências oficiais: [PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow), [redirecionamentos](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri), [modo de desenvolvimento](https://developer.spotify.com/documentation/web-api/concepts/quota-modes), [mudanças de playlists](https://developer.spotify.com/documentation/web-api/references/changes/february-2026).
