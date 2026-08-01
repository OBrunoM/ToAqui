# ToAqui — Visual Redesign v2 (Home / Locais / Contatos)

**Date:** 2026-08-01
**Status:** Approved

## Context

The app already has a Teal (`#2A9D8F`) / Coral (`#F4A261`) theme from the first visual refresh, plus the working family-invite/notifications and emergency-alert features built on this branch (`family-invite-notifications`). The human partner supplied three reference mockups (Home, Locais, Contatos) and asked for the visual language to be followed faithfully. This spec covers restyling those three screens and adding the small amount of real functionality the mockups imply (stats, tabs, last-arrival summary) — it does not add anything the mockups don't call for.

This branch (not master) is the base: the mockups' data (linked contacts, active locations, arrivals) only exists here, since master predates the Firestore-backed screens.

## Goals

- Restyle Home, Locais, and Contatos to match the supplied mockups: card shapes, spacing, iconography, gradient hero card, tabs, stat tiles.
- Back every number and list the mockups show with real data where that data already exists or is a small, natural extension (arrival history, active-location count, linked-contact count).
- Keep every existing real feature reachable (simulate-arrival trigger, active/inactive toggle, invite-code generation, delete contact) — restyled, never removed.

## Non-Goals (resolved during brainstorming, see rationale)

- **No deep linking / shareable URL** for invites — still the existing 6-character code; the mockup's `https://toaqui.app/...` link is visual only, not implemented.
- **No contact photo upload** — avatar stays an initial in a colored circle.
- **No contact phone number field** — dropped from the redesign; the app has no use for it (invite-code based, not phone-based).
- **No reverse geocoding** — location cards show coordinates, not a formatted street address.
- **No real background monitoring** — the "Online / GPS conectado / Sincronizado" status bar and "Monitoramento ativo" pill are fixed, optimistic visual elements, same as today's manual-simulation model (real geofencing is the separate, already-deferred Leva B).
- **No notifications screen or overflow menu** — the bell and 3-dot icons in the Home AppBar are visual only, no destination, in this pass.
- **No full arrival-history screen** — the Home "Ver todas" link next to "Últimas chegadas" is visual only in this pass (no destination screen).
- **No generic/standalone invite link on Home** — the Home invite card is a shortcut into the existing Contatos add-contact flow, not a new invite mechanism.

## Architecture

### Data additions

- `ArrivalRepository` gains a read method: `Stream<List<ArrivalRecord>> watchArrivals(String ownerUid)`, querying `arrivals` where `ownerUid == uid`, ordered by `createdAt` descending. `ArrivalRecord` is a new small model holding exactly what's stored (`id`, `locationId`, `message`, `createdAt`) — no location name or icon on the model itself. Home resolves the location's name/emoji for display by looking up `locationId` against the already-loaded `locationsStreamProvider` list. This is the first real read path for arrivals; today only `recordArrival` exists and Home renders hardcoded placeholder data.
- `LocationModel` gains one new field: `icon` (`String`, an emoji, default `'📍'`), settable via a small preset picker (🏠 🏢 🎓 🏥 🛒 📍) added to `AddLocationScreen`'s existing form. Mirrors the emoji icon language already used elsewhere in the app (empty states, etc.).
- Three small derived providers (Riverpod, computed from existing streams — no new Firestore reads beyond the one above):
  - `activeLocationsCountProvider` — count of `locations` where `isActive`.
  - `linkedContactsCountProvider` — count of `contacts` where `linkedUid != null`.
  - `arrivalsThisMonthCountProvider` — count of arrivals from `watchArrivals` whose `createdAt` falls in the current calendar month.

### Theme additions

Extend `AppTheme`/`AppColors` (not replace) with the tokens the new components need: a card corner radius constant (20), a soft elevation/shadow style, and a teal gradient (`primary` → a darker teal shade) for the Home hero card. Existing `ColorScheme` values (primary/secondary/surface) are reused everywhere else — this is restyling existing screens, not a new palette.

## Screens

### Home (`lib/screens/home_screen.dart`)

- **AppBar:** logo + "ToAqui" + new tagline "Sempre avisando quem importa." underneath. Trailing: a bell icon (static, small red dot badge, no destination) and a 3-dot overflow icon (static, no menu). The existing "Tenho um convite" entry point moves out of the AppBar into the invite card at the bottom of the screen (see below) so the real feature isn't lost.
- **Hero status card:** teal gradient container, shield-check icon in a circle, "Você está protegido", a static "Monitoramento ativo" pill, a divider, an "Última chegada" row sourced from `watchArrivals` (most recent entry — location name + relative time; if none yet, "Nenhuma chegada registrada ainda"), and a fixed closing line "Tudo funcionando normalmente." with a check icon.
- **Stats row:** three tiles — Locais ativos (`activeLocationsCountProvider`), Contatos avisados (`linkedContactsCountProvider`), Chegadas este mês (`arrivalsThisMonthCountProvider`).
- **SOS:** `EmergencyButton`'s hold-to-confirm logic is unchanged; only its `build()` becomes a full-width rounded banner ("SOS" + "Pressione por 3 segundos") with a fill-style progress indicator during the hold, instead of the current centered circular button.
- **Últimas chegadas:** header with a static "Ver todas" (no destination), list driven by `watchArrivals` — each row shows the location's emoji icon, name, relative time, "Chegada registrada com sucesso", and a trailing count of currently-linked contacts. Empty/loading states reuse `EmptyState`/`SkeletonListTile` as today.
- **Invite card:** static illustration + copy from the mockup, but its action (card tap or "Copiar link" button) navigates to the Contatos tab (existing bottom-nav route) and opens the existing add-contact sheet, rather than copying anything on Home directly. This is also where the old AppBar "Tenho um convite" link now lives, as a small text button.

### Locais (`lib/screens/locations_screen.dart`)

- Tabs: **Ativos** / **Inativos**, filtering the existing `locationsStreamProvider` list by `isActive` client-side (no new query).
- Each card: emoji icon (new `icon` field) in a circle, name, "Raio: {radius}m" (coordinates, not address, per the Non-Goals), an Ativo/Inativo chip, the existing on/off `Switch`, and a `⋮` overflow menu holding the existing "Simular chegada" action (previously a standalone bell `IconButton`). `LocationsScreen` has no delete action today, so none is added here — this redesign only relocates "Simular chegada" into the menu.
- FAB unchanged ("Novo Local" → `/locations/add`), and `AddLocationScreen` gains the small icon picker mentioned above.

### Contatos (`lib/screens/contacts_screen.dart`)

- Tabs: **Todos** / **Pendentes**, filtering the existing `contactsStreamProvider` list by `linkedUid == null` for Pendentes (no new query).
- Each card: initial-in-circle avatar (unchanged), name, a relationship chip/badge (reuses the existing free-text `relationship` field verbatim — "Principal", "Amiga", etc. are whatever the user typed, not a new enum), a small "Recebe todas as notificações" / "Convite pendente" line depending on `linkedUid`, and the existing delete action (moved into a `⋮` menu to match the mockup's layout).
- FAB unchanged ("Adicionar" → existing add-contact sheet + invite-code dialog flow).
- Bottom "Convide novos contatos" card mirrors the mockup, reusing the same add-contact entry point as the FAB (no new invite mechanism, per Non-Goals).

## Testing

- Widget tests updated for the three screens' new structure (tabs, stat tiles, hero card contents) using the existing `ProviderScope` override pattern with `fake_cloud_firestore`.
- New test for `ArrivalRepository.watchArrivals` (ordering, scoping to `ownerUid`), mirroring the existing repository test pattern.
- New tests for the three derived count providers (simple, given fixed input lists).
- `EmergencyButton`'s existing hold-gesture tests are updated only for the new widget tree shape (finder changes); the hold-duration/trigger logic and its tests are unchanged.
- No test hits a live Firebase project — same `fake_cloud_firestore`/`firebase_auth_mocks` pattern as the rest of this branch.
