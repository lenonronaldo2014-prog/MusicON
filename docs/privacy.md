# Privacidade do MusicON

O MusicON é um projeto independente de player Android. Não é afiliado ao Spotify, YouTube ou NewPipe.

## Dados no aparelho

Favoritos, playlists, cor do aplicativo e histórico de downloads ficam no armazenamento privado do app no seu aparelho. Arquivos baixados são guardados nesse armazenamento e podem ser removidos em Downloads ou pelo menu da música. Desinstalar o app pode remover esses dados; as versões com a mesma assinatura preservam a biblioteca ao atualizar.

## Biblioteca de músicas do celular

Com a sua permissão de áudio, o MusicON consulta o catálogo MediaStore do Android para encontrar músicas já presentes no armazenamento compartilhado. Essa leitura é local: nomes e artistas dos arquivos não são enviados a um servidor de catálogo do MusicON. O app acompanha mudanças e atualiza a biblioteca ao voltar ao primeiro plano. Você pode revogar a permissão nas configurações do Android; a leitura automática deixa de estar disponível até autorizá-la novamente.

A exclusão de arquivos locais só acontece após sua confirmação no aplicativo e, quando necessário, pelo próprio Android. Cancelar não exclui o arquivo. Remover um download interno mantém a referência online; excluir um arquivo do aparelho remove também suas referências nos favoritos e playlists do MusicON.

## Busca e reprodução

A fonte de busca recebe os termos que você informa. Ao buscar uma versão de uma música de uma playlist importada, o título e o artista dessa faixa são enviados à fonte de busca somente após sua ação. Serviços de reprodução recebem as requisições necessárias para fornecer o áudio e as capas. Esses serviços podem conhecer o endereço IP e informações técnicas da conexão.

## Spotify opcional

Se você conectar uma conta, pode escolher o aplicativo Spotify compatível instalado ou o navegador do aparelho, diretamente no Spotify. O MusicON não recebe sua senha. Solicita apenas leitura de playlists privadas e colaborativas para listar as coleções e permitir a transferência de seus metadados mediante sua escolha. A sessão é guardada cifrada com uma chave protegida pelo Android Keystore.

Você pode usar Desconectar na tela do Spotify para apagar a sessão. As listas recuperadas para navegação não são armazenadas em servidor do MusicON. As coleções que você confirmou para salvar na biblioteca do MusicON permanecem no aparelho. Você também pode revogar o acesso na página de aplicativos da sua conta Spotify.

A integração não baixa arquivos de áudio do Spotify. As versões escolhidas na busca do MusicON usam sua própria fonte para reprodução e download.

## Atualizações

A busca de atualizações consulta a API pública do GitHub. A consulta ocorre quando você toca em Buscar atualizações ou, se tiver habilitado essa opção, quando abre o aplicativo. GitHub recebe o IP e os dados técnicos usuais da conexão. O MusicON não inclui tokens de acesso ao GitHub no aplicativo.

## Contato

Dúvidas e solicitações sobre o projeto podem ser encaminhadas pelas [issues do repositório](https://github.com/lenonronaldo2014-prog/MusicON/issues). Não publique senhas, tokens nem dados privados nas issues.
