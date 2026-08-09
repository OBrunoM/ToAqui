<p align="center">
  <img src="assets/branding/logo.png" alt="Logo do ToAqui" width="110" />
</p>

<h1 align="center">ToAqui — Segurança para quem importa</h1>

<p align="center">
  Aplicativo mobile desenvolvido em Flutter e Firebase para facilitar o acompanhamento e a
  comunicação entre familiares e pessoas de confiança, com localização, alertas de emergência
  e notificações.
</p>

<p align="center">
  <img src="docs/screenshots/home.png" width="23%" alt="Tela Home" />
  <img src="docs/screenshots/localizacao.png" width="23%" alt="Tela de Localização" />
  <img src="docs/screenshots/contatos.png" width="23%" alt="Tela de Contatos" />
  <img src="docs/screenshots/emergencia.png" width="23%" alt="Botão de Emergência" />
</p>

---

O ToAqui nasceu de uma situação do meu dia a dia.

Por trabalhar e estudar longe de casa, preciso pegar a estrada diariamente. Como é natural, meus pais sempre ficam preocupados durante o trajeto e, quando eu esquecia de avisar que havia chegado ao meu destino, eles ficavam sem saber se estava tudo bem.

Foi a partir desse problema que surgiu a ideia do ToAqui: um aplicativo capaz de automatizar esse aviso.

O usuário configura um destino e cadastra seus familiares ou pessoas de confiança. Quando o aplicativo identifica que o usuário chegou próximo ao local definido, uma notificação é enviada automaticamente para essas pessoas, informando que ele chegou em segurança.

Além de automatizar o aviso de chegada, o ToAqui também possui um botão de emergência, pensado para permitir que o usuário peça ajuda rapidamente em situações de necessidade, inclusive em cenários onde a conexão com a internet ou o GPS esteja indisponível.

O funcionamento é simples:

1. O usuário define um destino.
2. Cadastra familiares ou pessoas de confiança.
3. O aplicativo acompanha o deslocamento.
4. Ao chegar próximo ao destino, o ToAqui identifica a chegada.
5. Os contatos recebem uma notificação informando que o usuário chegou.

E, em uma situação de emergência, o usuário pode acionar rapidamente o botão de emergência.

##  Conheça o ToAqui

<table>
  <tr>
    <td align="center" width="33%">
      <img src="docs/screenshots/home.png" width="100%" alt="Home" /><br />
      <b> Home</b><br />
      <sub>Status de monitoramento e chegadas recentes da família</sub>
    </td>
    <td align="center" width="33%">
      <img src="docs/screenshots/localizacao.png" width="100%" alt="Localização" /><br />
      <b> Localização</b><br />
      <sub>Locais cadastrados, com ícone e status ativo/inativo</sub>
    </td>
    <td align="center" width="33%">
      <img src="docs/screenshots/contatos.png" width="100%" alt="Pessoas de confiança" /><br />
      <b> Pessoas de confiança</b><br />
      <sub>Abas Todos/Pendentes, prontas para os primeiros convites da família</sub>
    </td>
  </tr>
  <tr>
    <td align="center" width="33%">
      <img src="docs/screenshots/emergencia.png" width="100%" alt="Emergência" /><br />
      <b> Emergência</b><br />
      <sub>Segurar por 3 segundos envia um alerta com localização</sub>
    </td>
    <td align="center" width="33%">
      <img src="docs/screenshots/convite.png" width="100%" alt="Convite" /><br />
      <b>🔗 Convite</b><br />
      <sub>Código de 6 caracteres, sem precisar de e-mail ou senha</sub>
    </td>
    <td align="center" width="33%">
      <sub><i>(em breve — print da notificação chegando no celular)</i></sub><br />
      <b> Notificações</b><br />
      <sub>Push em tempo real quando alguém chega ou pede ajuda</sub>
    </td>
  </tr>
</table>



##  Principais funcionalidades

**Frontend**
- Flutter + Dart, com gerenciamento de estado reativo (Riverpod)
- Navegação declarativa com `go_router`
- App multiplataforma: Android, iOS e Web a partir de uma única base de código

**Backend**
- Firebase (Authentication, Cloud Firestore, Cloud Messaging)
- Cloud Functions em TypeScript, disparadas por eventos do banco de dados
- Regras de segurança do Firestore escritas por coleção, com testes dedicados

**Recursos**
-  Geolocalização (cadastro de locais + simulação/registro de chegada)
-  Notificações push em tempo real
-  Sistema de convites (vínculo entre contas sem senha)
-  Alertas de emergência com garantia de envio


##  Decisões técnicas

**Por que Flutter?**
Pra manter uma única base de código cobrindo Android, iOS e Web, sem abrir mão de uma
interface nativa e responsiva. Como o projeto lida com permissões sensíveis (localização,
notificações), também pesou o acesso maduro do Flutter aos plugins nativos dessas APIs.

**Por que Firebase?**
Pra não precisar manter um servidor rodando 24 horas por dia só pra escutar "alguém chegou" ou
"alguém apertou o botão de emergência". O Firestore guarda os dados, e Cloud Functions reagem
a eventos (a criação de um documento) pra disparar as notificações — o backend inteiro é
orientado a evento, sem infraestrutura própria pra manter no ar.

**Por que autenticação anônima em vez de cadastro tradicional?**
Porque o cadastro tradicional é atrito puro pra esse caso de uso: ninguém quer criar senha só
pra avisar que chegou em casa. A identidade anônima resolve "quem é essa pessoa no sistema", e
o convite por código resolve "como ela se conecta à família dela" — sem precisar de nenhuma das
duas coisas depender de e-mail.

**Por que testar as regras do Firestore separadamente?**
Testes de widget e de repositório, sozinhos, não garantem que as regras de segurança do banco
de dados estão corretas — eles rodam contra um Firestore falso, que não aplica regra nenhuma.
Foi exatamente assim que uma falha real passou despercebida por várias rodadas de revisão neste
projeto: as regras permitiam, sem querer, que uma pessoa vinculasse a própria conta ao contato
pendente de outra família. A correção veio junto com uma suíte de testes dedicada, rodando
contra o emulador do Firestore, validando especificamente o que cada regra permite e proíbe.

**Por que o botão de emergência nunca pode "travar"?**
Porque numa emergência real, esperar o app não é uma opção. O fluxo de envio tem um limite de
tempo único para toda a etapa de localização (incluindo a permissão do sistema, que sozinha
pode ficar esperando resposta indefinidamente) — se a localização não vier a tempo, o alerta
sai mesmo assim, só que sem coordenadas.

##  Como rodar o projeto

Pré-requisitos: [Flutter SDK](https://docs.flutter.dev/get-started/install), um projeto
Firebase próprio (Auth anônimo + Firestore habilitados) e o
[Firebase CLI](https://firebase.google.com/docs/cli).

```bash
# instalar as dependências do app
flutter pub get

# rodar os testes do app
flutter test

# rodar o app (escolha um dispositivo/emulador disponível)
flutter run
```

Para o backend (Cloud Functions):

```bash
cd functions
npm install
npm run build

# rodar os testes contra o emulador do Firestore
firebase emulators:exec --only firestore "npm test"
```

> Este repositório não inclui chaves ou credenciais do Firebase de produção. Para rodar o
> projeto localmente, configure seu próprio projeto Firebase e gere o
> `lib/firebase_options.dart` com o [FlutterFire CLI](https://firebase.flutter.dev/docs/cli).
