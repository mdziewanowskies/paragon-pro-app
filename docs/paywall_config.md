# ParagonPro — Paywall Configuration

## App Overview
ParagonPro is a Polish financial assistant app for scanning receipts, tracking warranties, analyzing expenses, and integrating with KSeF (Polish National e-Invoice System). Available on iOS and Android, built with Flutter.

## Brand Identity
- **App Name**: ParagonPro
- **Tagline**: Twój inteligentny asystent finansowy
- **Primary Color**: #1F9663 (green)
- **Secondary Color**: #27C17F (light green)
- **Background**: #121212 (dark)
- **Accent**: #4DC98E
- **Logo**: Receipt-shaped P icon in green gradient
- **Language**: Polish (pl-PL)

## Target Audience
- Polish consumers who want to digitize paper receipts
- Small business owners tracking expenses and KSeF invoices
- Families sharing household expense tracking
- Age: 25-45, smartphone-savvy, value-conscious

## Entitlement
- **Entitlement Identifier**: `ParagonPro Pro`

## Products (3 options)

### 1. Monthly Subscription
- **Identifier**: `paragonpro_pro_monthly`
- **Price**: 29 zł/month
- **Free Trial**: 7 days
- **Auto-renewable**: Yes

### 2. Yearly Subscription
- **Identifier**: `paragonpro_pro_yearly`
- **Price**: 290 zł/year (saves ~17% vs monthly)
- **Free Trial**: 7 days
- **Auto-renewable**: Yes
- **Badge**: "Oszczędzasz 17%" / "Najpopularniejszy"

### 3. Lifetime Purchase
- **Identifier**: `paragonpro_pro_lifetime`
- **Price**: 499 zł (one-time)
- **Badge**: "Najlepsza wartość" / "Raz na zawsze"

## Free Plan Limitations
- 10 receipts per month
- Basic OCR only
- Basic analytics
- No KSeF integration
- No family sharing
- No PDF/CSV/XML export
- No priority support

## Pro Plan Features (what users unlock)
1. **Nielimitowane paragony** — Unlimited receipt scanning per month
2. **Zaawansowane AI OCR** — Advanced AI-powered receipt recognition with auto-categorization
3. **Pełna integracja KSeF** — Full integration with Polish National e-Invoice System (sync, download XML)
4. **Zaawansowana analityka** — Advanced expense analytics with charts, trends, category breakdown
5. **Eksport PDF/CSV/XML** — Export reports in multiple formats
6. **Konto rodzinne** — Family account with up to 5 members, shared receipts and stats
7. **Śledzenie gwarancji** — Warranty tracking with push notification reminders (30/7/1 day before expiry)
8. **Priorytetowe wsparcie** — Priority customer support
9. **Pismo reklamacyjne AI** — AI-generated complaint letters with PDF export
10. **Sklepy z logotypami** — Store aggregation with brand logos and spending insights

## Paywall Design Requirements

### Hero Section
- Title: **"Odblokuj pełnię ParagonPro"** or **"ParagonPro Pro"**
- Subtitle: **"7 dni za darmo — anuluj kiedy chcesz"**
- Background: Green gradient (#1F9663 → #27C17F)
- Icon: Premium crown or star in amber/gold

### Feature List (show 5-6 most compelling)
Display with green checkmark icons:
- ✅ Nielimitowane skanowanie paragonów
- ✅ Zaawansowane rozpoznawanie AI
- ✅ Integracja z KSeF
- ✅ Analityka wydatków i raporty
- ✅ Konto rodzinne do 5 osób
- ✅ Przypomnienia o gwarancjach

### Call to Action
- Primary button text: **"Wypróbuj 7 dni za darmo"** (for trial-eligible)
- Secondary: **"Kontynuuj"** or **"Wybierz plan"**

### Package Display
- Highlight the **yearly** plan as "Najpopularniejszy" with a badge
- Show monthly price equivalent for yearly (e.g., "24,17 zł/mies")
- Lifetime with "Jednorazowa płatność" label

### Social Proof (optional)
- "Dołącz do tysięcy Polaków, którzy oszczędzają z ParagonPro"
- "Średnio 200 zł oszczędności rocznie dzięki śledzeniu gwarancji"

### Legal Footer
- "Subskrypcja odnawia się automatycznie. Możesz anulować w dowolnym momencie."
- "Warunki korzystania" and "Polityka prywatności" links
- "Przywróć zakupy" link

### Restore Purchases
- Always visible as text link at the bottom
- Text: "Przywróć zakupy"

## Paywall Placement (where to show)
1. When free user tries to upload more than 10 receipts/month
2. When accessing KSeF integration features
3. When trying to export PDF/CSV/XML
4. When trying to create family account
5. From "Ulepsz do Pro" button in profile
6. From pricing route (/pricing)

## Localization
- All text in Polish (pl-PL)
- Currency: PLN (zł)
- Date format: dd.MM.yyyy

## A/B Test Suggestions
- Test "7 dni za darmo" vs "Wypróbuj Premium" as CTA
- Test feature list order (KSeF first vs unlimited scans first)
- Test showing/hiding lifetime option
- Test yearly-first vs monthly-first layout

## Customer Center
- Enable "Zarządzaj subskrypcją" button for active subscribers
- Show current plan, renewal date, and cancel option
- Allow plan switching (upgrade from monthly to yearly)

## Technical Notes
- Flutter app using `purchases_flutter` and `purchases_ui_flutter` SDK
- RevenueCat API Key: `test_NoVmdZvFeAgfvMQrhzdosZpdoLD`
- Supabase backend syncs subscription tier via webhook
- App supports dark mode only (dark theme)
