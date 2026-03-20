# ProfEF-BA com Supabase

Evolucao incremental do prototipo atual do ProfEF-BA para um fluxo TALP com sessao/token, mantendo o painel principal do professor e movendo a persistencia das respostas para o Supabase.

## O que foi preservado

- Layout principal do professor em [`profef-ba.html`](/home/alesandro/Documentos/Dev/profef-ba/profef-ba.html)
- Estrutura em 5 etapas do planejamento
- Analise local das palavras, matriz curricular e relatorio final
- Persistencia local do restante do planejamento via `localStorage`

## O que mudou

- O QR do aluno agora carrega apenas a URL da sessao TALP
- As respostas dos alunos deixam de trafegar no QR e passam a ser gravadas no Supabase
- A etapa 2 do professor passa a criar/abrir/encerrar sessoes TALP e ler respostas do banco
- O formulario do aluno em [`talp-aluno.html`](/home/alesandro/Documentos/Dev/profef-ba/talp-aluno.html) virou uma pagina minimalista por `token`
- O painel do professor voltou a usar login do Supabase para validar o prototipo com um fluxo mais seguro

## Setup

1. Crie um projeto no Supabase.
2. No SQL Editor, execute [`supabase/schema.sql`](/home/alesandro/Documentos/Dev/profef-ba/supabase/schema.sql).
3. Em `Authentication > Providers`, deixe `Email` habilitado.
4. Em `Authentication > Users`, crie o usuario de professor que vai validar o prototipo.
5. Edite [`supabase-config.js`](/home/alesandro/Documentos/Dev/profef-ba/supabase-config.js) com:
   - `url`
   - `anonKey`
   - `alunoPagePath` se a rota do aluno for diferente
6. Sirva os arquivos estaticos em um host HTTP/HTTPS. Exemplo simples:

```bash
python3 -m http.server 8080
```

7. Abra `http://localhost:8080/profef-ba.html`.

## Fluxo esperado

1. O professor entra no painel com uma conta real do Supabase Auth.
2. Na etapa 1, informa escola, turma, ano e professor.
3. Na etapa 2, cria ou abre uma sessao TALP.
4. O painel gera link e QR para [`talp-aluno.html`](/home/alesandro/Documentos/Dev/profef-ba/talp-aluno.html)`?token=...`.
5. O aluno abre o link, a pagina valida o token e so libera envio se a sessao estiver `open`.
6. O aluno envia exatamente 5 palavras e campos opcionais.
7. O professor atualiza a sessao e visualiza:
   - quantidade de respostas
   - lista das respostas
   - frequencia das palavras

## Modelo inicial

- `schools`: escola digitada no fluxo do professor
- `teachers`: perfil do professor vinculado a `auth.users`
- `classes`: turma vinculada ao professor e escola
- `talp_sessions`: sessao TALP com `draft/open/closed` e `qr_token`
- `talp_responses`: respostas anonimas enviadas pelos alunos

## RLS resumido

- Professor autenticado acessa apenas o proprio `teacher`, `classes`, `talp_sessions` e `talp_responses`
- Aluno anonimo nao faz `select` em respostas
- Aluno anonimo envia resposta apenas pela RPC `submit_talp_response`
- A RPC valida token e `status = 'open'`

## Observacoes

- A modelagem cobre a persistencia do novo fluxo TALP, que era o foco principal desta adaptacao.
- O restante do planejamento anual continua local, para evitar reescrita do frontend do professor nesta iteracao.
- A autenticacao do professor foi mantida simples, com uma conta do Supabase Auth para validar o prototipo sem expor administracao de sessao publicamente.
- Se quiser evoluir a proxima fase, o caminho natural e persistir tambem as etapas 1, 3, 4 e 5 no Supabase sem alterar o layout atual.
