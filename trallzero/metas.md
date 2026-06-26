# Metas - TrallZero

## ✅ Concluído

- [x] Roteirização com perfis de caminhão (leve, truck, carreta, bitrem, rodotrem)
- [x] Análise de declividade (rampas) por segmento da rota
- [x] Consulta de restrições OSM (peso, altura, largura, vias proibidas)
- [x] Exibição do mapa com rotas coloridas por nível de risco
- [x] Navegação GPS com câmera adaptativa e centralização inteligente
- [x] Bússola com fallback para sensor dummy
- [x] Velocímetro, direção cardeal e ETA em tempo real
- [x] Re-roteirização automática ao desviar da rota
- [x] Marcadores colaborativos (carga, descarga, restrição, balança, estacionamento)
- [x] Busca de endereços via Nominatim com debounce
- [x] Guia por voz (text-to-speech)
- [x] Tema escuro Material 3 (alto contraste para dirigir)
- [x] 5 perfis de caminhão configuráveis (peso, eixos, altura, comprimento)
- [x] Instruções passo a passo (turn-by-turn) no painel de navegação
- [x] Botões "Rotas" com função real
- [x] Botão "Evitar" com função real
- [x] Refatorar MapButton para componente reutilizável
- [x] Tela de mapa expandido (fullmap_view)
- [x] Alerta de fadiga (Lei 13.103) com timer e aviso por voz
- [x] Tela de configurações (perfil padrão salvo offline, TTS toggle)
- [x] Design system centralizado (AppColors + AppTheme em lib/core/)
- [x] Fix busca: bounded=1 removido do Nominatim (não suprime mais destinos distantes)
- [x] Busca por CEP via ViaCEP com geocodificação automática (CepService)
- [x] Timeout de 15s em todas as requisições HTTP (Nominatim, OSRM, ViaCEP)
- [x] Persistência do timer de fadiga entre sessões (Lei 13.103 — salva a cada 30s, restaura ao reabrir)
- [x] Redesenho do painel peek em modo navegação (foco total na manobra ativada)
- [x] Marcador de veículo personalizado (NavigationMarker) que muda de formato com o tipo de caminhão (articulado/reboques) e cor/pulso com a velocidade
- [x] HUD de velocidade em fullscreen (glassmorphic com bússola e relógio no topo direito)
- [x] Animação de início de rota (fly-in) suave e dramática de 1.5s ao dar GO
- [x] Legenda rápida interativa (Tooltip on Tap) na barra de perfil de risco da rota
- [x] SnackBar premium flutuante customizado (showStyledSnackBar) com ícones e bordas semânticas
- [x] Filtro de precisão do satélite GPS (accuracy <= 20m) para evitar loops de recálculos de rota por drift
- [x] Fallback automático para voz em português genérico (pt-BR -> pt) no motor de TTS

## 🔄 Em Andamento / Próximas

- [ ] Backend Node.js com rotas e banco de dados

## 📋 Pendente

- [ ] Sincronização em nuvem dos marcadores
- [ ] Compartilhamento de rotas entre motoristas
- [ ] Contas de usuário / autenticação
- [ ] Gestão de frotas
- [ ] Modo offline (cache de tiles e dados)
- [ ] Histórico de rotas
- [ ] Notificações de alerta (radar, balança, estrada perigosa)
- [ ] Integração com pedágio e custos de rota
- [ ] Quebrar MapScreen (1955 linhas) em widgets menores
