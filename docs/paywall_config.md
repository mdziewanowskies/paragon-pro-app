# ParagonPro — Paywall Configuration

## App Overview
ParagonPro is a Polish financial assistant app for scanning receipts, tracking warranties, analyzing expenses, and integrating with KSeF (Polish National e-Invoice System). iOS and Android, built with Flutter.

## Brand Identity
- **App Name**: ParagonPro
- **Tagline**: Twój inteligentny asystent finansowy
- **Primary Color**: #1F9663 (green)
- **Accent**: #27C17F (light green)
- **Background**: #121212 (dark only)
- **Language**: Polish (pl-PL)
- **Currency**: PLN (zł)

## Entitlement
- **Entitlement Identifier**: `ParagonPro Pro`

## Products (2 options)

### Monthly Subscription
- **Price**: 19,99 zł/month
- **Free Trial**: 7 days
- **Auto-renewable**: Yes

### Yearly Subscription
- **Price**: 179,99 zł/year (saves 20% vs monthly)
- **Free Trial**: 7 days
- **Auto-renewable**: Yes
- **Badge**: "Oszczędzasz 20%"
- **Monthly equivalent**: 15,00 zł/miesiąc

## Free Plan (what users get without paying)
- 5 paragonów/miesiąc
- Podstawowe OCR
- Brak integracji KSeF
- Brak konta rodzinnego
- Brak eksportu PDF/CSV/XML

## Premium Features (what users unlock)
1. ✅ Nielimitowane skanowanie paragonów
2. ✅ Zaawansowane rozpoznawanie AI
3. ✅ Pełna integracja z KSeF
4. ✅ Zaawansowana analityka wydatków
5. ✅ Konto rodzinne do 5 osób
6. ✅ Przypomnienia o gwarancjach
7. ✅ Eksport PDF, CSV i XML

## Paywall Design

### Hero
- Title: **ParagonPro Premium**
- Subtitle: **7 dni za darmo — anuluj kiedy chcesz**
- Icon: Gold/amber crown/star

### CTA Button
- **"Wypróbuj 7 dni za darmo"**
- Yearly plan selected by default

### Plan Toggle
- **Miesięcznie**: 19,99 zł
- **Rocznie**: 179,99 zł + badge "-20%"
- Yearly highlighted by default

### Footer
- "Przywróć zakupy" link
- Auto-renewal disclaimer
- Privacy policy / Terms links

## Restrictions (Free → Premium)
| Feature | Free | Premium |
|---------|------|---------|
| Paragony/miesiąc | 5 | Nielimitowane |
| KSeF | ❌ | ✅ |
| Konto rodzinne | ❌ | ✅ |
| Eksport | ❌ | ✅ |
| AI OCR | Podstawowe | Zaawansowane |
| Analityka | Podstawowa | Zaawansowana |
