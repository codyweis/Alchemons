# Alchemical party hat prototype

A shared procedural cosmetic: violet particle cone, rotating gold spirals, gold brim and sparkling tip. The animated preview uses static creature artwork to isolate the hat motion. Head placements are manually fitted for Waterlet, Firepip and Lighthorn; animated head tracking, shop ownership and per-creature equipment are not implemented.

The reusable Flutter overlay is `AlchemicalPartyHatView` in `lib/widgets/fx/alchemical_party_hat.dart`. It wraps a sized sprite and accepts a normalized head attachment and width. Its painter can also be called directly by a Flame host.

Render preview frames:

```sh
PARTY_HAT_OUT=/tmp/alchemical_party_hat PARTY_HAT_FONT='/System/Library/Fonts/Supplemental/Arial.ttf' flutter test test/party_hat_preview_test.dart
```

Use any local TTF path for PARTY_HAT_FONT. The exported GIF shows the eight-second loop.
