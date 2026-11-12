# mTAB

Sélecteur de fenêtres macOS (clone personnel d'AltTab avec les fonctions Pro), Swift/AppKit/SwiftUI, sans dépendance.
Interface : suivre le design system Socle — https://claude.ai/artifact/TkNj2Y6SQGZwT6EyME92Ah (copie locale : /Volumes/SKYRIM/TOOLS/DESIGN/Socle ; `Sources/Socle.swift` en est la copie, à resynchroniser).

- `./build.sh` : compile, produit `build/mTAB Dev.app` (fr.stephan.mtab.dev) et ma version locale `~/Applications/Applications Personnelles/mTAB.app`. `DEV_ONLY=1` : dev seulement.
- Ni notarisation ni push sans demande (« compile, notarise et pousse »). Reste à faire : release.sh, mise à jour automatique (modèle mBACKUP/Updater.swift), dépôt GitHub privé.
- Autorisations : Accessibilité (raccourcis, actions) et Enregistrement de l'écran (aperçus).
- Textes : `Sources/L10n.swift`, 4 langues (fr, en, es, it).
