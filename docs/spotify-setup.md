# Conectar o MusicON ao Spotify

O login é opcional. O aplicativo lê metadados das playlists autorizadas pela conta; não recebe arquivos de áudio do Spotify nem baixa músicas do Spotify. O usuário escolhe versões encontradas na busca do MusicON antes de importar uma coleção. Downloads offline usam a fonte da faixa escolhida no MusicON.

## Situação desta entrega

O Client ID público informado para o MusicON foi configurado a partir da versão 0.7.0. Desde a versão 0.7.2, os dois modos de login usam **`musicon://spotify/callback`**, já aceito no painel do projeto. O Android recebe o retorno e reabre o MusicON; não há dependência de servidor HTTP dentro do aplicativo.

No emulador, a versão anterior foi observada congelada pelo Android em segundo plano, com o servidor de retorno sem responder. O novo caminho permite que o sistema descongele e traga o MusicON para a frente. Ao atualizar, feche a autorização antiga no navegador e inicie uma tentativa nova. O retorno antigo `http://127.0.0.1:8888/callback` pode continuar cadastrado para versões anteriores.

O aviso do painel de que a Web API está bloqueada por falta de Premium é um bloqueio independente do retorno de login. A conta responsável pelo cadastro precisa atender à exigência do Spotify. Trocar apenas a conta que entra no MusicON não elimina esse requisito.

## Cadastro necessário

1. Entre no [Spotify for Developers](https://developer.spotify.com/dashboard) com a conta responsável pelo aplicativo.
2. Cadastre o MusicON com a Web API.
3. Cadastre o redirecionamento **`musicon://spotify/callback`**. Desde 0.7.2, esse é o endereço usado tanto pelo navegador quanto pelo aplicativo Spotify.
4. Informe a política de privacidade pública: `https://github.com/lenonronaldo2014-prog/MusicON/blob/main/docs/privacy.md`.
5. Envie ao responsável pela compilação somente o **Client ID público**. Não envie Client Secret, senha nem tokens.
6. Em Users Management, adicione as contas de teste permitidas.

O Client ID é o identificador público gerado no cadastro. A exigência paga documentada para desenvolvimento é a conta Premium do responsável, não uma chave a comprar separadamente. No modo de desenvolvimento atual, o responsável pelo cadastro precisa de Spotify Premium e há limite de cinco contas autenticadas na lista de autorizados. Playlists de terceiros podem fornecer apenas metadados, sem o conteúdo; a importação depende do acesso que a API concede à conta. Não há tentativa de contornar essa restrição.

## Escolher o modo de login

O botão Conectar ao Spotify permite escolher **Pelo aplicativo Spotify** ou **Pelo navegador**. A opção de aplicativo só fica ativa quando a biblioteca oficial reconhece um Spotify compatível e com assinatura válida no aparelho. O fluxo usa Authorization Code com PKCE, valida o estado e utiliza o armazenamento cifrado existente. Cancelar não conecta a conta. O navegador continua disponível.

Para habilitar a autorização nativa no cadastro do MusicON, em Settings no painel Spotify:

1. Mantenha `http://127.0.0.1:8888/callback` e adicione também **`musicon://spotify/callback`** em Redirect URIs.
2. Marque Android nas APIs utilizadas. Na configuração Android, cadastre o pacote **`com.musicon.musicon.prototype`**.
3. Cadastre a impressão SHA-1 da assinatura usada nestes APKs: **`86:93:7C:70:1D:8D:69:0E:5D:97:00:BF:10:6E:69:AE:87:37:21:31`**.
4. Salve. Se a assinatura do APK mudar no futuro, atualize também esse cadastro.

O navegador precisa do endereço `musicon://spotify/callback` cadastrado. O pacote Android e a assinatura são utilizados para a autorização pelo aplicativo Spotify. A biblioteca Spotify Android Auth 5.0.0 verifica a instalação e a assinatura do Spotify; seu utilitário nativo entrega o resultado diretamente à Activity do MusicON. Pelo navegador, o mesmo endereço de retorno é tratado pela MainActivity do MusicON, sem uma segunda Activity receptora ou servidor loopback. O fluxo aceita somente um login em andamento e valida o estado antes de entregar o código.

O login pode aguardar até dez minutos. Cancelar invalida a tentativa. Se o Android encerrar completamente o processo do MusicON durante o login, abra o app e conecte novamente; o retorno de uma tentativa encerrada não cria sessão.

## Compilar com o cadastro

```powershell
flutter build apk --release -t lib/main_newpipe.dart --dart-define=SPOTIFY_CLIENT_ID=SEU_CLIENT_ID_PUBLICO
```

O Client ID público do projeto já é o valor padrão; a opção acima permite substituí-lo em outra compilação. Incremente versão e build antes de publicar uma atualização. Preserve a assinatura usada nas entregas anteriores.

O Client ID é um identificador público, não um segredo. O fluxo é Authorization Code com PKCE S256: o navegador trata o login e o aplicativo valida `state` no retorno. Não há Client Secret no APK. Os tokens são cifrados com AES-GCM usando uma chave no Android Keystore; o app permite desconectar e apagar a sessão. O botão de login precisa de um navegador instalado.

## Falha de conexão com o servidor

Se aparecer “Não foi possível localizar o servidor do Spotify”, a rede do celular não conseguiu resolver o endereço do serviço. Isso ocorre antes de validar o Client ID ou a conta. A partir da versão 0.7.1, o MusicON faz até duas novas tentativas para falhas de DNS e mostra uma orientação em português. Tente outra rede (Wi-Fi/dados móveis); se usa VPN, bloqueador ou DNS privado personalizado, teste sem ele e toque em **Tentar conectar novamente**. Atualizar o app não remove um bloqueio ou uma falha persistente da rede.

Falhas de rede não apagam uma sessão já salva. Timeouts ou respostas de erro do Spotify não repetem automaticamente o envio de códigos de login.

## Importação de playlists

Somente o link não substitui a conexão da conta nesta implementação. O endpoint atual permite obter as faixas de playlists que a conta possui ou em que colabora; links de outras playlists podem retornar acesso negado, mesmo quando são públicos.

Biblioteca > Importar do Spotify, ou Configurações > Spotify. Depois da conexão, escolha uma playlist ou use o link dela. Toque em cada faixa para escolher uma versão encontrada no MusicON. Só as seleções confirmadas são salvas, na ordem original. A importação pode ser parcial, e resultados podem ser versões diferentes da gravação do Spotify; a escolha é do usuário. Depois, use o download na playlist do MusicON se quiser disponibilizá-la offline.

Referências oficiais: [PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow), [redirecionamentos](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri), [modo de desenvolvimento](https://developer.spotify.com/documentation/web-api/concepts/quota-modes), [mudanças de playlists](https://developer.spotify.com/documentation/web-api/references/changes/february-2026).
