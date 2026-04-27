# Route Contracts: Upload-First Subject Creation

## Teacher Subject Routes

| Method | Path | Controller#Action | Purpose |
|--------|------|-------------------|---------|
| GET | /teacher/subjects/new | subjects#new | Upload form (2 PDF fields only) |
| POST | /teacher/subjects | subjects#create | Upload PDFs → create Subject(:uploading) → start extraction |
| GET | /teacher/subjects/:id | subjects#show | Extraction status polling (Turbo Frame) |
| GET | /teacher/subjects/:id/validation | subjects/validation#show | Pre-filled validation form |
| PATCH | /teacher/subjects/:id/validation | subjects/validation#update | Confirm → assign ExamSession → transition to :draft |

## Validation Form Params (PATCH)

```
params[:subject][:title]               # string — exam session title
params[:subject][:year]                # string — e.g. "2024"
params[:subject][:exam]                # enum string: "bac" | "bts" | "autre"
params[:subject][:region]              # enum string: "metropole" | "reunion" | "polynesie" | "candidat_libre"
params[:subject][:variante]            # enum string: "normale" | "remplacement"
params[:subject][:specialty]           # enum string: "sin" | "itec" | "ee" | "ac"
params[:subject][:exam_session_choice] # "attach" | "create"
params[:subject][:exam_session_id]     # integer — only present when choice == "attach"
```

## Response Contracts

### subjects#create (POST)
- Success: redirect 302 to `/teacher/subjects/:id` (show page, extraction polling)
- Failure (missing PDFs): render :new with 422

### subjects/validation#show (GET)
- Always renders: never redirects (even on failed extraction — shows empty form with error message)
- Template variables: `@metadata`, `@existing_session`, `@extraction_failed`

### subjects/validation#update (PATCH)
- Success: redirect 302 to `/teacher/subjects/:id` with notice "Sujet créé avec succès."
- Failure (validation errors): render :show with 422
