# 🚚 TrallZero — Navegação e Roteamento para Transporte de Carga

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-v3.11.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Plataforma-Android%20%7C%20iOS-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Plataformas" />
  <img src="https://img.shields.io/badge/Design-Material%203%20Dark-212121?style=for-the-badge&logo=material-design&logoColor=white" alt="Design" />
</p>

O **TrallZero** é um assistente de navegação inteligente e aplicativo de GPS dedicado para motoristas de transporte de carga e caminhoneiros. Ele foi projetado para oferecer rotas inteligentes considerando as dimensões do veículo (peso, altura, quantidade de eixos) e conta com um sistema de alertas colaborativos em tempo real na via.

---

## ✨ Funcionalidades Principais

* 🛣️ **Roteamento Inteligente (OSRM):** Geração de trajetos inteligentes para veículos pesados, evitando vias com restrições físicas de altura, largura ou pontes de baixo peso de suporte.
* 📍 **Alertas Colaborativos em Tempo Real:**
  * **Carga/Descarga:** Sinalização de áreas de carga e descarga de mercadorias.
  * **Radares de Velocidade:** Alertas dinâmicos para radares e pardais na pista.
  * **Outros Pontos de Interesse (POIs):** Balanças, postos de combustível, pátios de descanso, oficinas mecânicas, policiamento e áreas de perigo na via.
* 📸 **HUD Proativo de Alertas:** Painel visual dinâmico com contagem regressiva em metros ao se aproximar de radares ou zonas perigosas identificadas ao longo da rota.
* 🚚 **Cursores de Navegação 3D em Alta Fidelidade:** Representação visual fiel na tela de acordo com o perfil do veículo selecionado (*Caminhão Baú, Carreta, Bitrem, Rodotrem*), equipados com detalhes realistas como cabines, retrovisores e contêineres corrugados.
* 🔄 **Snapping GPS Inteligente:** Algoritmo premium de alinhamento de coordenadas à via com recálculo e desvio automático de rota baseado na tolerância fina de 35 metros.
* 🗣️ **Instruções por Voz (TTS):** Suporte para conversão de texto em fala a fim de guiar o motorista de maneira segura sem necessidade de desviar a atenção da estrada.
* 🕵️ **Reconhecimento de Texto com IA (OCR):** Integração com Google ML Kit para escaneamento e processamento de documentos ou placas de carga.

---

## 🛠️ Tecnologias & Bibliotecas Utilizadas

* **Framework:** [Flutter](https://flutter.dev) (Dart)
* **Gerenciamento de Estado:** [Provider](https://pub.dev/packages/provider)
* **Mapas e Georreferenciamento:**
  * `flutter_map` — Visualização do mapa base CartoDB Dark.
  * `latlong2` — Cálculos matemáticos de latitude/longitude.
  * `geolocator` & `flutter_compass` — Localização GPS precisa e orientação por bússola.
* **Persistência de Dados Local:**
  * `sqflite` — Banco de dados SQLite offline.
  * `shared_preferences` — Salvamento de configurações de perfil e UI.
* **Inteligência Artificial & Utilitários:**
  * `google_mlkit_text_recognition` — OCR para leitura e escaneamento.
  * `flutter_tts` — Motor de síntese de voz nativo do dispositivo.

---

## 📂 Organização do Projeto (Arquitetura)

O código-fonte está estruturado de maneira organizada e limpa, dividindo a lógica de negócio dos componentes visuais:

```
lib/
├── controllers/       # Regras de negócio, fluxo do mapa e gerência de rotas (Ex: TruckController)
├── core/              # Temas escuros Material 3, constantes e utilidades globais
├── features/          # Recursos modulares do aplicativo (Home, Gerenciador de Rotas/Paradas)
├── models/            # Modelagem de dados e classes nativas (Ex: Marcadores, Perfis de Caminhão)
├── screens/           # Telas principais da aplicação (Mapa, Perfil, Configurações, Login)
├── services/          # Conexão com APIs externas (OSRM), armazenamento SQLite, GPS e Preferências
└── widgets/           # Componentes visuais compartilhados (HUD de Alerta, Cursor do Veículo, Drawer)
```

---

## 🚀 Como Executar o Projeto Localmente

### Pré-requisitos
* Flutter SDK instalado (versão estável mais recente).
* Dispositivo físico Android/iOS ou Emulador com suporte a serviços de localização.

### Passos de Instalação

1. Clone o repositório em sua máquina:
   ```bash
   git clone https://github.com/seu-usuario/trallzero.git
   ```

2. Acesse a pasta do projeto:
   ```bash
   cd trallzero
   ```

3. Instale todas as dependências do Pubspec:
   ```bash
   flutter pub get
   ```

4. Execute o aplicativo em modo de desenvolvimento:
   ```bash
   flutter run
   ```

---

## 📜 Licença

Este projeto é privado e de uso proprietário exclusivo da marca **Trall**.
Todos os direitos reservados.
