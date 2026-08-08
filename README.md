<p align="center">
  <img src="assets/branding/logo.png" alt="Logo do ToAqui" width="120" />
</p>

<h1 align="center">ToAqui — Segurança para quem importa</h1>

<p align="center">
  Aplicativo mobile desenvolvido para facilitar o acompanhamento de pessoas importantes para você,
  oferecendo localização, contatos de confiança e alertas de emergência.
</p>

---

## 🎯 Sobre o projeto

Saber que quem você ama chegou bem em algum lugar — ou conseguir pedir ajuda rápido quando algo dá errado — não deveria depender de mandar mensagem e esperar resposta.

O **ToAqui** nasceu pra resolver esse problema de um jeito simples e direto: você cadastra os lugares que importam (casa, trabalho, escola), convida as pessoas de confiança da sua família, e a partir daí elas recebem um aviso automático sempre que você chega em um desses lugares. Em uma emergência, um botão de SOS — segurado por 3 segundos — dispara um alerta com sua localização pra todos os seus contatos vinculados, mesmo se a localização não puder ser obtida na hora (o envio nunca fica bloqueado esperando permissão ou GPS).

Não existe cadastro tradicional (e-mail, senha) — cada pessoa entra de forma anônima e se conecta às outras só através de um código de convite de 6 caracteres, sem depender de infraestrutura extra de autenticação.

## 📱 Funcionalidades

- 🚨 **Alerta de emergência** — botão de segurar-para-confirmar que envia localização (quando disponível) e notifica todos os familiares vinculados, com prioridade alta de entrega (Android e iOS)
- 📍 **Localização** — cadastro de locais com ícone, mapa e status ativo/inativo; simulação de chegada dispara notificação em tempo real
- 👥 **Pessoas de confiança** — lista de contatos com status de vínculo (pendente/conectado)
- 🔗 **Convite por link/código** — vínculo entre contas sem exigir e-mail ou senha, com expiração e uso único do código
- 🔔 **Notificações push** — entrega em tempo real via Firebase Cloud Messaging, disparada por Cloud Functions no backend

## 🛠️ Tecnologias

| | |
|---|---|
| 📱 **Flutter** | app multiplataforma (Android/iOS/Web), gerenciamento de estado com Riverpod |
| 🔥 **Firebase** | plataforma de backend |
| 🗄️ **Firestore** | banco de dados em tempo real, com regras de segurança escritas e testadas por coleção |
| ☁️ **Firebase Functions** | lógica de backend em TypeScript, disparada por eventos do banco de dados |
| 🔐 **Autenticação** | Firebase Auth anônimo, com vínculo entre contas via convite |
| 🧪 **Testes** | testes de widget/unidade em Flutter, testes de integração das Cloud Functions no emulador, e testes dedicados das regras de segurança do Firestore |

## 🏗️ Arquitetura

- **App Flutter**: navegação com `go_router`, estado reativo com Riverpod, repositórios dedicados por domínio (locais, contatos, convites, chegadas, emergências) sobre o Cloud Firestore.
- **Backend serverless**: duas Cloud Functions (`onArrivalCreated`, `onEmergencyCreated`) escutam a criação de documentos no Firestore e disparam push notifications para os contatos vinculados de cada usuário — sem precisar de um servidor rodando 24/7.
- **Segurança como prioridade**: as regras do Firestore foram escritas para que cada usuário só acesse os próprios dados e os dados que lhe foram explicitamente compartilhados via convite, e são cobertas por testes automatizados dedicados (não apenas testes de UI, que não validam regras de segurança).
- **Confiabilidade no caminho crítico**: o fluxo de emergência foi projetado para nunca deixar de enviar o alerta por causa de localização indisponível, permissão não respondida ou erro de rede — o envio sempre acontece, com ou sem coordenadas.

## 📸 Screenshots

_(em breve — capturas de tela das telas de Home, Locais, Contatos e do alerta de emergência)_

## 🚀 Como rodar o projeto

Pré-requisitos: [Flutter SDK](https://docs.flutter.dev/get-started/install), um projeto Firebase próprio (Auth anônimo + Firestore habilitados) e o [Firebase CLI](https://firebase.google.com/docs/cli).

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

> Este repositório não inclui chaves ou credenciais do Firebase de produção. Para rodar o projeto localmente, configure seu próprio projeto Firebase e gere o `lib/firebase_options.dart` com o [FlutterFire CLI](https://firebase.flutter.dev/docs/cli).
