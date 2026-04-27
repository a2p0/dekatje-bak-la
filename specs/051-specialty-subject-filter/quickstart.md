# Quickstart: Filtrage des sujets par spécialité de classe

## Scénarios de test manuels

### Prérequis
```bash
bin/rails db:seed  # charge development.rb — classes AC + EE + sujets + élèves
```

### Scénario 1 — Élève AC, sujet AC (accès complet)
1. Aller sur `/{access_code-ac}`
2. Se connecter avec `anya.ac / eleve123`
3. Liste des sujets → le sujet AC s'affiche **sans** mention "partie commune uniquement"
4. Ouvrir le sujet → parties communes ET spécifiques AC accessibles

### Scénario 2 — Élève EE, sujet AC (accès TC uniquement)
1. Aller sur `/{access_code-ee}`
2. Se connecter avec `anya.ee / eleve123`
3. Liste des sujets → le sujet AC s'affiche avec le badge **"partie commune uniquement"**
4. Ouvrir le sujet → seules les parties communes sont accessibles
5. Tenter d'accéder via URL directe à une partie spécifique AC → redirection avec message informatif

### Scénario 3 — Élève EE avec clé tuteur, partie commune sujet AC
1. Se connecter avec `tuteur.ee / eleve123` (élève EE avec clé tuteur)
2. Ouvrir le sujet AC → accéder à une question de la partie commune
3. Le bouton tuteur est disponible → lancer une session tuteur → fonctionne normalement

### Scénario 4 — Bypass URL bloqué
1. Se connecter avec un élève EE
2. Récupérer l'URL d'une question appartenant à une partie spécifique AC
3. Coller l'URL directement → redirection avec message "Question introuvable" ou "Accès non autorisé"

## Données seeds attendues après `db:seed`

| Classe | Spécialité | Access code | Élèves |
|--------|-----------|-------------|--------|
| Terminale STI2D AC 2025 | AC | terminale-ac-2025 | anya.ac, tuteur.ac (avec clé) |
| Terminale STI2D EE 2025 | EE | terminale-ee-2025 | anya.ee, tuteur.ee (avec clé) |

| Sujet | Spécialité | Parties |
|-------|-----------|---------|
| Sujet BAC STI2D AC (existant) | AC | TC + SPE AC |
| Sujet BAC STI2D EE (nouveau seed) | EE | TC + SPE EE |
