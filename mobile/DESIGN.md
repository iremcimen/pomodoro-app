# Pomo mobile design system

Pomo is an operational, cross-platform productivity interface. The visual
language is quiet and direct: warm coral marks action and progress, tinted
neutral surfaces create hierarchy, and the timer remains the dominant object.

## Foundations

- Color lives in `lib/app/theme/app_colors.dart`. Feature code should consume
  `Theme.of(context).colorScheme`; direct palette imports are reserved for
  brand assets that must keep a fixed identity.
- Spacing, radii, and motion constants live in
  `lib/app/theme/app_tokens.dart`. Add a token only when the same intent appears
  at least three times.
- Component defaults live in `lib/app/theme/app_theme.dart`. Prefer theme-level
  changes over one-off button, card, input, navigation, and dialog styling.
- Cards group one coherent set of controls or data. Do not nest cards or create
  a card for every small piece of information.

## Shared presentation components

- `AppShell` owns authenticated navigation, responsive breakpoints, page titles,
  and logout. Narrow layouts use `NavigationBar`; layouts from 760 px use
  `NavigationRail`.
- `ResponsiveContent` keeps task surfaces readable without forcing feature
  pages to repeat width constraints.
- `AppAsyncValueView` owns loading, error, retry, and state replacement.
  `AppStateMessage` is the shared empty/error message pattern.

Feature-specific widgets stay next to their feature until the same intent is
used in at least three places.

## Motion

Motion is functional and restrained. Frequent countdown ticks do not animate.
State swaps such as start/pause and loading/content use short opacity/scale
transitions. All authored motion must use `AppMotion.resolve`, which returns a
zero duration when the platform requests reduced motion. Avoid continuous,
bouncy, or attention-seeking animation.

## Accessibility

- Interactive icons require tooltips or an explicit semantic label.
- Progress indicators expose a readable semantic value.
- Loading and important status changes use live regions only when an
  announcement is useful; the one-second countdown is intentionally not live.
- Controls remain usable when animations are disabled.
