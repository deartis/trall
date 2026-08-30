import 'package:flutter/material.dart';

/// Design system de cores do Trall.
///
/// Toda cor hardcoded no projeto deve ser substituída por uma
/// constante daqui. Isso garante consistência visual e facilita
/// futuras mudanças de tema (ex: modo diurno).
abstract final class AppColors {
  // ─────────────────────────────────────────────────────────────
  //  Marca / Primária
  // ─────────────────────────────────────────────────────────────

  /// Âmbar principal — cor de identidade do Trall.
  static const Color amber = Color(0xFFE07B1A);

  /// Âmbar mais quente (ícones, destaques secundários).
  static const Color amberWarm = Color(0xFFFF9A3C);

  // ─────────────────────────────────────────────────────────────
  //  Fundos (do mais escuro ao menos escuro)
  // ─────────────────────────────────────────────────────────────

  /// Fundo mais profundo — usado em scaffolds e app bars.
  static const Color bgDeep = Color(0xFF0B0E17);

  /// Fundo base da aplicação.
  static const Color bgBase = Color(0xFF0E1017);

  /// Fundo levemente elevado (cards, painéis).
  static const Color bgPanel = Color(0xFF111318);

  /// Fundo de cards sobre o painel.
  static const Color bgCard = Color(0xFF161922);

  /// Fundo de itens de lista / tiles.
  static const Color bgTile = Color(0xFF1A1D26);

  /// Fundo de campos de input / dropdowns.
  static const Color bgInput = Color(0xFF1E2128);

  /// Fundo de input alternativo (mais azulado).
  static const Color bgInputAlt = Color(0xFF1E2535);

  /// Fundo escuro com toque azul (gradientes, overlays).
  static const Color bgNavy = Color(0xFF0F3460);

  /// Fundo alternativo escuro (ex: telas de perfil).
  static const Color bgAlt = Color(0xFF131720);

  /// Fundo levemente mais claro (gradientes superiores).
  static const Color bgGradientTop = Color(0xFF1A2035);

  /// Fundo de área com destaque âmbar suave.
  static const Color bgAmber = Color(0xFF0E1320);

  // ─────────────────────────────────────────────────────────────
  //  Semânticas — Status / Alertas
  // ─────────────────────────────────────────────────────────────

  /// Verde — seguro, sucesso, confirmado.
  static const Color safe = Color(0xFF34C759);

  /// Verde alternativo (usado em OAuth Google).
  static const Color safeAlt = Color(0xFF34A853);

  /// Amarelo — atenção, aviso leve.
  static const Color attention = Color(0xFFFF9500);

  /// Amarelo para análise de rota (iOS-style warning).
  static const Color attentionRoute = Color(0xFFFF9F0A);

  /// Âmbar escuro — aviso moderado.
  static const Color warning = Color(0xFFF59E0B);

  /// Laranja — perigo, sobrecarga.
  static const Color heavy = Color(0xFFFF6B00);

  /// Vermelho — crítico, erro, perigo imediato.
  static const Color danger = Color(0xFFFF3B30);

  /// Vermelho alternativo (análise de rota iOS).
  static const Color dangerRoute = Color(0xFFFF453A);

  /// Vermelho vivo (debug/placeholder).
  static const Color red = Color(0xFFFF0000);

  /// Amarelo brilhante — destaque em mapa (ex: risco máximo).
  static const Color yellow = Color(0xFFFFD60A);

  // ─────────────────────────────────────────────────────────────
  //  Azuis / Ação
  // ─────────────────────────────────────────────────────────────

  /// Azul principal — ação, navegação, links.
  static const Color blue = Color(0xFF2563EB);

  /// Azul médio — variante de ação secundária.
  static const Color blueMid = Color(0xFF3B82F6);

  /// Azul iOS — chips, badges.
  static const Color blueIos = Color(0xFF007AFF);

  /// Azul claro — informação, sugestão.
  static const Color blueLight = Color(0xFF1E90FF);

  /// Azul Google (OAuth).
  static const Color blueGoogle = Color(0xFF4285F4);

  // ─────────────────────────────────────────────────────────────
  //  Outros
  // ─────────────────────────────────────────────────────────────

  /// Roxo — tags, categorias especiais.
  static const Color purple = Color(0xFFAF52DE);

  /// Rosa — tags alternativas.
  static const Color pink = Color(0xFFEC4899);

  /// Cinza médio — ícones desativados, texto terciário.
  static const Color grey = Color(0xFF8E8E93);

  /// Cinza escuro — bordas, divisores.
  static const Color greyDark = Color(0xFF6B7280);

  /// Vermelho Google (OAuth).
  static const Color redGoogle = Color(0xFFEA4335);

  /// Amarelo Google (OAuth).
  static const Color yellowGoogle = Color(0xFFFBBC05);

  // ─────────────────────────────────────────────────────────────
  //  Helpers de opacidade (evitar .withValues() espalhados)
  // ─────────────────────────────────────────────────────────────

  /// Âmbar com 8% de opacidade (fundo de item selecionado).
  static Color get amberFaint => amber.withValues(alpha: 0.08);

  /// Âmbar com 12% de opacidade (fundo de chip/badge).
  static Color get amberSubtle => amber.withValues(alpha: 0.12);

  /// Âmbar com 18% de opacidade (fundo de card destacado).
  static Color get amberMuted => amber.withValues(alpha: 0.18);

  /// Âmbar com 25% de opacidade (bordas suaves).
  static Color get amberBorder => amber.withValues(alpha: 0.25);

  /// Âmbar com 40% de opacidade (texto secundário âmbar).
  static Color get amberDim => amber.withValues(alpha: 0.40);

  /// Âmbar com 45% de opacidade (chip selecionado).
  static Color get amberSelected => amber.withValues(alpha: 0.45);

  /// Verde com 12% de opacidade.
  static Color get safeSubtle => safe.withValues(alpha: 0.12);

  /// Verde com 30% de opacidade (bordas de sucesso).
  static Color get safeBorder => safe.withValues(alpha: 0.30);

  /// Azul com 12% de opacidade.
  static Color get blueSubtle => blue.withValues(alpha: 0.12);

  /// Azul com 25% de opacidade (bordas de ação).
  static Color get blueBorder => blue.withValues(alpha: 0.25);

  /// Vermelho com 12% de opacidade.
  static Color get dangerSubtle => danger.withValues(alpha: 0.12);

  /// Vermelho com 30% de opacidade (bordas de erro).
  static Color get dangerBorder => danger.withValues(alpha: 0.30);

  /// Vermelho com 40% de opacidade (bordas de erro mais visíveis).
  static Color get dangerBorderStrong => danger.withValues(alpha: 0.40);

  /// Vermelho com 15% de opacidade (fundo de alerta crítico).
  static Color get dangerFaint => danger.withValues(alpha: 0.15);

  /// Branco com 6% (divisores, separadores muito sutis).
  static Color get divider => Colors.white.withValues(alpha: 0.06);

  /// Branco com 18% (handles de drag sheet).
  static Color get handle => Colors.white.withValues(alpha: 0.18);

  /// Branco com 24% (bordas de cards).
  static Color get border => Colors.white.withValues(alpha: 0.24);

  /// Branco com 35% (texto terciário).
  static Color get textTertiary => Colors.white.withValues(alpha: 0.35);

  /// Branco com 40% (texto secundário).
  static Color get textSecondary => Colors.white.withValues(alpha: 0.40);

  /// Branco com 50% (ícones e labels menos importantes).
  static Color get textMuted => Colors.white.withValues(alpha: 0.50);

  /// Branco com 60% (ícones e texto normal de suporte).
  static Color get textSupport => Colors.white.withValues(alpha: 0.60);

  /// Branco com 80% (texto de conteúdo).
  static Color get textContent => Colors.white.withValues(alpha: 0.80);

  /// Preto com 60% (sombras).
  static Color get shadow => Colors.black.withValues(alpha: 0.60);
}
