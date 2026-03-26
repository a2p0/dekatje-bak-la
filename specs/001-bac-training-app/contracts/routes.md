# Routes Contract

**Branch**: `001-bac-training-app` | **Date**: 2026-03-26

## Namespace Teacher (`/teacher/...`)

```
GET    /teacher/login              → sessions#new
POST   /teacher/login              → sessions#create (Devise)
DELETE /teacher/logout             → sessions#destroy

GET    /teacher/dashboard          → dashboard#index
GET    /teacher/classrooms         → classrooms#index
POST   /teacher/classrooms         → classrooms#create
GET    /teacher/classrooms/:id     → classrooms#show
GET    /teacher/classrooms/:id/students → students#index
POST   /teacher/classrooms/:id/students → students#create (bulk)
PATCH  /teacher/students/:id/reset_password → students#reset_password

GET    /teacher/subjects           → subjects#index
GET    /teacher/subjects/new       → subjects#new
POST   /teacher/subjects           → subjects#create (upload PDF)
GET    /teacher/subjects/:id       → subjects#show
GET    /teacher/subjects/:id/validate → subjects#validate (interface validation)
PATCH  /teacher/subjects/:id/publish  → subjects#publish
PATCH  /teacher/subjects/:id/unpublish → subjects#unpublish

GET    /teacher/questions/:id/edit → questions#edit
PATCH  /teacher/questions/:id      → questions#update
DELETE /teacher/questions/:id      → questions#destroy

GET    /teacher/extraction_jobs/:id → extraction_jobs#show (statut SSE)
```

## Namespace Student (`/{access_code}/...`)

```
GET    /:access_code               → sessions#new (login élève)
POST   /:access_code/session       → sessions#create
DELETE /:access_code/session       → sessions#destroy

GET    /:access_code/subjects      → subjects#index
GET    /:access_code/subjects/:id  → subjects#show
GET    /:access_code/subjects/:id/parts/:part_id/questions/:id → questions#show

POST   /:access_code/questions/:id/answers → answers#create (saisie réponse)
POST   /:access_code/questions/:id/feedback → feedback#create (feedback IA)
POST   /:access_code/questions/:id/conversations → conversations#create
POST   /:access_code/conversations/:id/messages → messages#create (tutorat)

GET    /:access_code/settings      → settings#edit (clé API élève)
PATCH  /:access_code/settings      → settings#update
POST   /:access_code/settings/test → settings#test_key
```

## Flux SSE (streaming)

```
GET /teacher/subjects/:id/extraction_status   → SSE statut extraction
GET /:access_code/conversations/:id/stream    → SSE réponses tutorat
```
