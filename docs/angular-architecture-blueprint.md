# Angular Architecture Blueprint (ProfEF-BA)

## Objetivo
Migrar o app atual para Angular recente com:
- `tap-aluno` como arquivo estático
- tela de login para professor
- dashboard inicial com avaliações em andamento/finalizadas
- módulo de planejamento separado por etapas

## Stack sugerida
- Angular (versão estável mais recente)
- TypeScript strict
- Angular Router com lazy loading
- Signals + service store (sem NgRx no início)
- LocalStorage como persistência inicial

## Estrutura de pastas
```text
src/
  app/
    core/
      auth/
        auth.service.ts
        auth.guard.ts
        session.model.ts
      storage/
        local-storage.repository.ts
      qr/
        qr-payload.service.ts
      core.module.ts

    shared/
      components/
        app-version-badge/
        app-empty-state/
        app-confirm-dialog/
      pipes/
      directives/
      shared.module.ts

    features/
      auth/
        pages/login-page/
          login-page.component.ts
          login-page.component.html
          login-page.component.scss
        auth.routes.ts

      dashboard/
        pages/dashboard-page/
          dashboard-page.component.ts
          dashboard-page.component.html
          dashboard-page.component.scss
        components/
          evaluation-card/
        services/
          dashboard.service.ts
        dashboard.routes.ts

      planning/
        pages/planning-shell/
        pages/planning-step-1/
        pages/planning-step-2/
        pages/planning-step-3/
        pages/planning-step-4/
        pages/planning-step-5/
        services/
          planning-store.service.ts
          evaluation.service.ts
          pdf-export.service.ts
          scanner.service.ts
        planning.routes.ts

    models/
      evaluation.model.ts
      planning.model.ts
      talp-payload.model.ts

    app.routes.ts
    app.component.ts

  assets/
    static/
      tap-aluno.html
```

## Roteamento
```text
/login                       -> login professor
/dashboard                   -> avaliações em andamento/finalizadas (home)
/planning/new               -> cria avaliação e abre etapa 1
/planning/:id/step/1        -> contextualização
/planning/:id/step/2        -> diagnóstico TALP
/planning/:id/step/3        -> unidades didáticas
/planning/:id/step/4        -> matriz curricular
/planning/:id/step/5        -> relatório final
```

## Domínio (contratos)

### EvaluationStatus
- `draft`
- `completed`

### Evaluation
- `id: string`
- `teacherId: string`
- `status: 'draft' | 'completed'`
- `createdAt: string`
- `updatedAt: string`
- `plan: PlanData`

### PlanData
- campos das etapas 1..5 (contexto, TALP, unidades, matriz, relatório)
- `scanResponses: StudentResponse[]`

### TalpPayload (QR)
Compatível com `tap-aluno` estático:
- `t: string[]`
- `p?: string[]`
- `d?: string`
- `i?: string`
- `b?: string`

## Módulos e responsabilidades

### Core
- autenticação/sessão
- guardas de rota
- repositório de persistência
- parser/encoder de payload QR (único para scanner e colagem)

### Auth
- login/logout
- manutenção da sessão do professor

### Dashboard
- listar avaliações `draft` e `completed`
- ações: criar, abrir para edição, excluir, duplicar

### Planning
- fluxo por etapas
- estado do formulário (store local)
- salvar rascunho
- finalizar avaliação
- exportar PDF sem alterar dados automaticamente

## Persistência local (fase 1)
Chaves sugeridas:
- `profef_session_v1`
- `profef_evaluations_v1`
- `profef_ui_v1` (opcional)

Estratégia:
- cada avaliação salva por `id`
- dashboard filtra por `status`
- ao abrir avaliação para edição, manter `id` e atualizar `updatedAt`

## `tap-aluno` estático
- servir em `assets/static/tap-aluno.html`
- mantém geração de `PROFEF:<base64>`
- Angular consome com o mesmo parser no scanner e no "colar código"

## Guardrails de UX
- login obrigatório para `/dashboard` e `/planning/**`
- botão de versão no topo (`v0.0.01` inicial)
- dashboard sempre como tela inicial após login
- scanner com fallback: câmera, foto, colagem manual

## Sequência de implementação (sprints)

### Sprint 1 (fundação)
1. criar workspace Angular
2. módulos: `core`, `shared`, `auth`, `dashboard`, `planning`
3. rotas e guard
4. login mock + sessão local

### Sprint 2 (domínio)
1. modelos de avaliação
2. repositório local
3. dashboard com listagem draft/completed
4. criar/abrir/excluir avaliação

### Sprint 3 (planejamento)
1. shell + etapas 1..5
2. store de planejamento
3. salvar rascunho e finalizar

### Sprint 4 (QR e PDF)
1. scanner + parser único
2. importar por foto/colar código
3. exportar PDF
4. ajustes mobile

## Critérios de pronto
- login obrigatório funcionando
- dashboard como home do professor
- edição de avaliação por ID sem duplicação indevida
- importação QR funcional (scanner/foto/colar)
- exportação PDF funcional
- `tap-aluno` estático interoperando com Angular
