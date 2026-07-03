---
name: grill-with-docs
description: Use to pressure-test a product, architecture, domain model, refactor, migration, or implementation plan before code changes. Runs a focused technical interview that surfaces contradictions, missing requirements, edge cases, rollout hazards, and tradeoffs, then records decisions as ADRs and domain terms in project docs.
---

# Grill With Docs

Use this skill when the user wants a plan sharpened, a design challenged, or an ambiguous decision turned into documented engineering intent.

## Grounding

Before asking questions:

1. Inspect the relevant repo context: existing docs, routes, schema/migrations, models, services, jobs, views, tests, Docker/config files, and prior tradeoff notes.
2. Identify the decision surface:
   - product behavior
   - domain model
   - data model or migration
   - architecture boundary
   - integration/API contract
   - rollout/operations
   - testing strategy
3. State a concise current read: what appears decided, what is unclear, and what could break if the plan is wrong.

Do not ask questions that inspection can answer.

## Interview Loop

Ask one high-impact question at a time. Keep going until the plan is coherent enough to implement or the remaining unknowns are explicitly accepted.

Prioritize questions in this order:

1. User-visible behavior and success criteria.
2. Domain language and ownership boundaries.
3. Data shape, invariants, lifecycle, and deletion/rollback semantics.
4. API, background job, and external service contracts.
5. Edge cases, failure modes, retries, idempotency, and race conditions.
6. Rollout, migration, operational visibility, and support/debuggability.
7. Security, privacy, authorization, and abuse cases.
8. Test coverage and verification commands.

Push back directly when an answer conflicts with code reality, production quality, or another stated requirement. If a tradeoff is accepted, document it instead of burying it in conversation.

## Documentation Outputs

Create or update docs as the session converges.

ADR path:

```text
docs/adr/YYYY-MM-DD-<decision-slug>.md
```

ADR template:

```markdown
# <Decision Title>

Status: proposed | accepted | superseded
Date: YYYY-MM-DD

## Context
What forced this decision, including codebase constraints and user-visible goals.

## Decision
The chosen approach in concrete terms.

## Alternatives Considered
- <alternative>: why rejected.

## Consequences
Benefits, costs, migration impact, operational impact, and known risks.

## Verification
Tests, commands, browser checks, review steps, or observability that prove the decision works.

## Revisit Condition
The condition that should cause this ADR to be reopened or retired.
```

Glossary path:

```text
docs/glossary.md
```

Glossary entry format:

```markdown
## <Term>

Definition: <plain product/domain definition>
Owner: <bounded context or subsystem>
Notes: <important invariants, examples, or non-examples>
```

If the session accepts an intentional tradeoff, also add a note under:

```text
.agents/tradeoffs/YYYY-MM-DD-<tradeoff-slug>.md
```

Include context, rejected alternatives, impact, verification, and retirement condition.

## Closeout

End the session with:

- Decisions made.
- Docs created or updated.
- Open questions that still block implementation.
- Accepted tradeoffs and where they are documented.
- The implementation constraints that future code work must honor.

Do not implement code as part of a grilling session unless the user explicitly pivots from design review to implementation.
