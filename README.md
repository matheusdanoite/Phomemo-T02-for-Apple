# Phomemo T02

Este projeto consiste em uma aplicação iOS e uma Web App (React) para permitir a impressão de imagens e textos em impressoras Phomemo T02 via Bluetooth, utilizando o Firebase para sincronização entre dispositivos.

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

## Funcionalidades
- Conexão Bluetooth com Phomemo T02.
- Processamento de imagem em tempo real (Dithering).
- Compartilhamento de impressora entre dispositivos (Host/Client mode).
- Atalhos da Siri (App Intents) para impressão rápida de texto e área de transferência.

---
Desenvolvido por **matheusdanoite**.
