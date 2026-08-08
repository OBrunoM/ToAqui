# Screenshots do ToAqui

Salve os prints aqui, com exatamente estes nomes, que o README principal já está
com os caminhos prontos — nenhuma edição extra necessária.

| Arquivo | Tela | O que capturar |
|---|---|---|
| `home.png` | 🏠 Home | Tela inicial com o card de status, o botão de emergência e a lista de chegadas recentes |
| `localizacao.png` | 📍 Localização | Lista de locais cadastrados (ativos/inativos) ou a tela de adicionar um local |
| `contatos.png` | 👨‍👩‍👧 Pessoas de confiança | Lista de contatos, mostrando alguém conectado e alguém com convite pendente |
| `emergencia.png` | 🚨 Emergência | O botão de SOS em destaque, se possível durante o "segurar" (com a barra de progresso visível) |
| `convite.png` | 🔗 Convite | O código de convite gerado, ou a tela "Tenho um convite" preenchida |
| `notificacao.png` | 🔔 Notificações | A notificação push chegando no celular (print da tela de bloqueio/central de notificações) |

Para os 3-4 destaques grandes logo no topo do README, escolha as fotos que ficarem
melhor visualmente entre essas seis — não precisa duplicar arquivos, o topo do
README pode reaproveitar os mesmos nomes.

**Como tirar os prints:** instale o `ToAqui-app-debug.apk` (gerado nesta sessão,
está na sua Área de Trabalho) em um Android e navegue pelas telas, ou rode
`flutter run -d chrome` — nesse caso, note que a tela de Localização crashava por
falta da chave do Google Maps (ainda pendente de configurar).

## Fluxo em GIF (opcional, mas recomendado)

Um GIF curto (5-10s) mostrando: criar convite → copiar código → outra pessoa
redime o código → aparece como conectado. Ferramentas simples pra gravar a tela
do celular e converter em GIF: o próprio gravador de tela do Android/iOS +
[ezgif.com](https://ezgif.com/video-to-gif) pra converter o vídeo. Salve como
`convite-flow.gif` nesta mesma pasta.
