# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-02-20

### Adicionado
- **App iOS (t02web)**:
    - Conexão Bluetooth estável com impressoras Phomemo T02.
    - Suporte a modo **Host/Client** para compartilhamento de impressora em rede local via P2P.
    - Integração com **Firebase Firestore** para sincronização de filas de impressão.
    - **App Intents**: Suporte a atalhos Siri para imprimir texto e área de transferência.
    - Suporte a background printing e tratamento de permissões Bluetooth.
    - UI adaptativa para iPhone, iPad e macOS (Mac Catalyst).
- **Web App (Vite/React)**:
    - Processamento de imagem local com algoritmos de **Dithering** (Floyd-Steinberg, Halftone, etc.).
    - Interface moderna e responsiva para seleção e pré-visualização de imagens.
    - Sincronização automática com o App iOS via Firebase.

### Melhorado
- Estilização da Web App para uma experiência mais premium.
- Lógica de roteamento de conexões Bluetooth para evitar conflitos de papéis.
- Tratamento de erros de build e compatibilidade cross-platform (iOS/macOS).

### Corrigido
- Crashes relacionados à restauração de estado do Bluetooth.
- Problemas de carregamento de assets locais no WebView do iOS.
- Inconsistências na formatação de texto multi-linha para impressão.

---
Desenvolvido com ❤️ por **matheusdanoite**.
