# ToAqui — Visual Refresh & Local UI Interactions

**Date:** 2026-07-29
**Status:** Approved

## Context

ToAqui is a Flutter app that notifies family members when someone arrives at a
saved location (geofencing). A full review of the existing codebase (`lib/`)
found the app functional as a UI prototype with mocked/in-memory data, but with
gaps in both appearance and functionality. This spec covers the **appearance +
local UI interaction** slice only. A separate future spec will cover the
technical foundation (Firebase, permissions, real geofencing, persistence,
push notifications) and is explicitly out of scope here.

Visual direction was chosen collaboratively via mockups (browser-based visual
companion): palette, icon/illustration style, the Add Location screen layout,
and the app icon concept were each validated against 2-3 options before this
spec was written.

## Goals

- Replace the current cyan Material 3 theme with a warmer "caloroso e
  familiar" identity (Teal & Coral palette).
- Adopt a playful, illustrated/emoji icon language for status cards and empty
  states, while keeping Material icons for utilitarian UI (nav bar, small
  action buttons).
- Fix the cramped 50/50 map/form split on Add Location with a full-map +
  draggable bottom sheet layout.
- Add the missing UI states across the app: loading (skeleton), empty
  (illustrated), and error (banner/snackbar) — using one consistent pattern.
- Make the Contacts ("Família") screen locally interactive (add/delete in an
  in-memory list) instead of fully static, without wiring any backend.
- Concept an app icon ("cozy house") to be generated via
  `flutter_launcher_icons`.

## Non-Goals

- No Firebase integration, no real persistence across app restarts.
- No Android/iOS location permission setup, no Google Maps API key setup.
- No real geofencing wiring or push notifications.
- No final app icon artwork production — a placeholder in the new palette is
  acceptable until final art is supplied.

## Visual Identity

- **Palette:** primary Teal `#2A9D8F`, accent Coral `#F4A261`, background
  cream `#F7F3ED`, dark text tones in green (`#2A5A54` / `#5B3A1E` family as
  used in mockups). Replaces the seed color `0xFF00B4D8` in `main.dart`'s
  `ThemeData` for both light and dark themes.
- **Icon/illustration language:** large emoji/illustration used for card
  hero moments and empty states (e.g., 🏡, 👨‍👩‍👧‍👦, 💌). Material icons
  (outline/filled pairs) remain for the bottom nav and small inline actions —
  no wholesale icon replacement there.
- **Shape/elevation:** rounded cards (12-20px radius), soft shadows tinted
  with the palette color rather than plain black, consistent with the
  mockups validated in the companion.
- **App icon:** conceptually a house on a coral gradient, generated with the
  `flutter_launcher_icons` package from a single source image. A placeholder
  source image in-palette is fine for this pass; final artwork can replace it
  later without further design work.

## Screens

### Home
- Recolor the status card to the new palette; structure unchanged.
- "Últimos Envios" list: skeleton placeholders while loading; if empty, an
  illustrated empty state matching the pattern used elsewhere (not just
  plain text).

### Locais (Locations)
- List gets skeleton loading.
- Toggling a location's active switch shows a confirmation **snackbar**
  (e.g., "Casa desativado").
- Existing empty state ("Nenhum local cadastrado") gets an illustration/emoji
  treatment matching the new pattern.

### Família (Contacts)
- No longer fully static:
  - New local-only state (e.g., a `ContactModel` + a `StateNotifier` provider
    analogous to `LocationNotifier`, in-memory only, no persistence).
  - Empty state: illustration (👨‍👩‍👧‍👦) + title + CTA button.
  - "Adicionar" opens a form/modal (name + relationship) that inserts into
    the local list.
  - Delete button actually removes the contact from the local list.

### Adicionar Local (Add Location)
- Replace the fixed 50/50 `Expanded` split with a full-screen map and a
  draggable bottom sheet (`DraggableScrollableSheet` or equivalent) holding
  the form fields (name, radius slider, message, save button). Dragging the
  sheet up reveals the full form; collapsed state shows just enough to save
  quickly.

### Navigation / Main Layout
- No structural changes — same 3 tabs (Início, Locais, Família) — just
  recolored to the new palette.

## Shared UI States

One consistent pattern is used app-wide instead of ad hoc handling per screen:

- **Loading:** skeleton placeholders (pulsing blocks shaped like the eventual
  content), used on Home and Locais list loads.
- **Empty:** illustration/emoji + short title + short subtitle + CTA where
  applicable (Família, Locais, Home).
- **Error:** banner/snackbar styled distinctly from the confirmation snackbar
  (different accent color), following the same component so it's ready for
  use once real network calls exist in a future pass — not heavily exercised
  yet since there's no backend in this slice.
- **Local action feedback:** snackbar confirmation for toggling a location's
  active state.

## Testing

This is a UI-focused pass with in-memory state only:
- Widget tests for the new Contacts provider (add/delete/list) mirroring the
  existing `LocationNotifier` pattern.
- Manual verification of each screen's loading/empty/error state rendering
  and the Add Location bottom-sheet interaction (drag up/down, save).
- No integration/e2e tests needed since no backend is involved yet.
