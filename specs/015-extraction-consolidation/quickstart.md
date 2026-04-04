# Quickstart: Consolidation de l'extraction PDF

## Prérequis

- Ruby 3.3+, Rails 8.1
- PostgreSQL (Neon ou local)
- Redis (pour Sidekiq)
- Un fichier sujet BAC STI2D officiel (PDF) + son corrigé pour tester

## Lancer les migrations

```bash
bin/rails db:migrate
```

## Tester l'upload (enseignant)

1. Se connecter comme enseignant
2. Aller sur "Nouveau sujet"
3. Remplir les métadonnées (titre, année, spécialité, région)
4. Uploader 2 fichiers : sujet PDF + corrigé PDF
5. Lancer l'extraction (automatique)
6. Vérifier la structure extraite : parties communes + spécifiques

## Tester la déduplication (même session)

1. Uploader un 2e sujet (spécialité différente) en sélectionnant la session existante
2. Vérifier que les parties communes ne sont pas dupliquées
3. Vérifier que seules les parties spécifiques sont créées

## Tester le profil élève

1. Se connecter comme élève
2. Aller dans les paramètres
3. Sélectionner une spécialité
4. Vérifier la persistance

## Tester la navigation élève

1. Accéder à un sujet rattaché à une ExamSession
2. Choisir un périmètre (commune / spé / complet)
3. Vérifier que seules les questions du périmètre sont affichées
4. Changer de périmètre et vérifier que la progression est conservée

## Lancer les tests

```bash
bundle exec rspec spec/models/exam_session_spec.rb
bundle exec rspec spec/services/
bundle exec rspec spec/features/
```
