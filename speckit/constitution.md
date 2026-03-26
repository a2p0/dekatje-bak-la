# Constitution — DekatjeBakLa

## Identité produit
**DekatjeBakLa** — "décrocher le bac" en créole martiniquais.
Application web d'entraînement aux examens BAC, multi-matières, multi-bac.
Contexte : établissements scolaires français, élèves mineurs, Martinique.

---

## Principes non-négociables

### Architecture
- Rails 8 fullstack uniquement. Hotwire/Turbo Streams pour toute l'interactivité.
- Les appels IA partent TOUJOURS du serveur Rails, jamais du navigateur.
- Un seul déploiement Coolify pour l'app Rails. Redis et Neon sont des services externes.

### RGPD et protection des mineurs
- Aucune inscription libre. L'enseignant crée tous les comptes élèves.
- Aucun email élève collecté ni stocké.
- Les élèves se connectent via identifiant + mot de passe uniquement.
- Les données d'un élève sont isolées à sa classe.
- Une page de politique de confidentialité est obligatoire avant production.

### Sécurité
- Les clés API (enseignant et élève) sont chiffrées avec `encrypts` (Rails natif).
- Le `RAILS_MASTER_KEY` ne figure jamais dans le code versionné.
- Aucun secret dans les logs, jamais.
- Le fallback clé serveur (`ANTHROPIC_API_KEY`) n'est jamais exposé au client.

### Qualité
- TDD obligatoire : test RSpec écrit et qui échoue AVANT le code de production.
- Thin controllers : toute logique dans `app/services/`.
- Migrations écrites et validées avant les modèles ActiveRecord.
- Une Pull Request = une feature = une branche.

### Expérience utilisateur
- Interface en français. Code (variables, méthodes, routes) en anglais.
- Mode 0 (lecture) : gratuit, 0 appel IA.
- Mode 1 (révision) : clé élève requise pour le feedback IA.
- Mode 2 (tutorat) : clé élève requise, streaming obligatoire.
- L'agent tutorat ne donne jamais la réponse directement — il guide.
- L'extraction PDF est toujours asynchrone. L'enseignant voit le statut en temps réel.
- La validation enseignant est obligatoire par défaut avant publication.

### Performance (contexte Martinique)
- Interface légère. Assets compilés localement, pas de CDN externe.
- Timeout appels IA : 60 secondes minimum.
- PDF max : 20 MB (sujets), 50 MB (leçons).

### Données
- Soft delete sur Subject et Question (`discarded_at`), jamais de suppression définitive.
- Deux URLs Neon distinctes : poolée (app) et directe (migrations uniquement).

---

## Définition du "done"

Une feature est terminée quand :
1. Tests RSpec passent (unitaires + intégration)
2. Migration propre et réversible (`db:rollback` fonctionne)
3. Interface fonctionnelle sur Chrome et Firefox
4. Aucune clé API ni secret dans les logs
5. Review Superpowers validée
6. RGPD : aucune donnée élève inutile collectée
