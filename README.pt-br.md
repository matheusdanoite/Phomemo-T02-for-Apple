# Phomemo T02 for Apple
[English version](README.md)

Third time's the charm! Na minha terceira iteração sobre uma forma de conectar meus Apple Devices a uma impressora Phomemo T02, este projeto consiste em uma aplicação iOS e uma Web App (React) para permitir a impressão de imagens e textos em impressoras deste modelo via Bluetooth, utilizando o Firebase para permitir que terceiros enviem dados para serem impressos localmente via Bluetooth. Eu adoro esse modelo de impressora!

## Como Funciona
Funciona assim: você pode fazer o deploy — ou não — em um endereço da internet, e então quem acessar essa página vai poder enviar arquivos para impressão na sua impressora. Ao enviar um arquivo, ele é convertido para Base64 e enviado ao Firebase. Quando o app deste repositório recebe a graça do iOS para rodar em segundo plano, ele pergunta por novidades. Havendo novidades, o Firebase transmite os dados, que são decodificados no dispositivo e impressos via Bluetooth. Uma vez impressos, eles são deletados do Firebase.

### Conexão Multipeer
Também adicionei uma feature na qual é possível compartilhar a impressora com outras pessoas rodando o mesmo aplicativo. É criada uma conexão multipeer utilizando a framework MultipeerConnectivity da Apple para permitir exatamente isso: uma conexão multipeer, ou seja, uma rede local sem um servidor central. Quando um dispositivo abre o app, ele automaticamente inicia no modo cliente. Neste modo, ele busca por outros dispositivos disponíveis no modo host ou impressoras para conexão; ao conectar-se com uma impressora, ele assume o papel de host. Como host, o papel dele é rotear todos os trabalhos de impressão recebidos para a impressora, inclusive os dos clientes conectados.

### App Intents e Atalhos
Há também o suporte aos App Intents: é possível imprimir um texto ou a área de transferência via Siri, Atalhos, ou qualquer outra parafernália da Apple. Há dois intents: um para imprimir texto e imagens e outro para imprimir a área de transferência. O texto e imagem é o meu favorito: um espaço para imagem, seguido por um título e um texto. Eu fiz um fax com impressão de mensagens que recebo via iMessage e uso como colecionador de momentos: tiro uma foto, escrevo uma legenda e imprimo com o título configurado para puxar a data e hora de criação da foto. Legal, né? Nos encontros a galera geralmente gosta.

## Estrutura do Projeto
- **/iOSApp**: Contém o projeto Xcode (.xcodeproj) e o código-fonte em Swift. O aplicativo gerencia a conexão Bluetooth com a impressora e atua como Host ou Client de impressão.
- **/WebApp**: Contém o frontend em React (Vite) utilizado para processar imagens (algoritmos de dithering como Floyd-Steinberg) antes de enviá-las para impressão.

## Como Configurar
### 1. Firebase (Obrigatório)
O projeto utiliza o Firebase Firestore e Storage. Para rodar, você precisará dos seus próprios arquivos de configuração:

1. Crie um projeto no [Firebase Console](https://console.firebase.google.com/).
2. **iOS**:
   - Adicione um aplicativo iOS ao seu projeto Firebase.
   - Baixe o arquivo `GoogleService-Info.plist`.
   - Coloque-o em `iOSApp/GoogleService-Info.plist` (use o arquivo `.example` como referência).
3. **Web**:
   - Adicione um Web App ao seu projeto Firebase.
   - Copie as credenciais e preencha o arquivo `WebApp/src/firebaseConfig.js` (use o arquivo `firebaseConfig.example.js` como referência).

### 2. Rodando a Web App
```bash
cd WebApp
npm install
npm run dev
```

### 3. Rodando o App iOS
Abra `iOSApp/t02web.xcodeproj` no Xcode, certifique-se de configurar seu *Development Team* na aba *Signing & Capabilities* e execute em um dispositivo físico (Bluetooth é necessário).

## Considerações Finais
Os trabalhos de impressão são todos processados no dispositivo de origem, e ele também fica ótimo no macOS — também dá pra buildar ele para um Mac. Foi vibecoded até não querer mais, mas eu peço desculpas por isso — pelo menos funcionou aqui.

Desenvolvido por **matheusdanoite chaebol**.