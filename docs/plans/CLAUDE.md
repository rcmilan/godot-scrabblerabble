# Documentation/Plans Directory

## Purpose
Contains feature design documents and implementation plans for Wordatro features. Each feature has paired design and plan documents.

## Key Files
- `2026-02-21-decks-design.md` - Design specification for deck selection feature
- `2026-02-21-decks-plan.md` - Implementation plan for deck selection feature

## Public Interfaces
None (documentation only)

## Dependencies
None

## Architecture / Patterns
**Two-Document Pattern**:
- **Design Document** (`*-design.md`): Defines the "what" and "why"
  - Overview and goals
  - Design principles (OOP, DDD, cyclomatic complexity)
  - Domain model specifications
  - API contracts and behavioral specifications
  - Integration points
  - Status tracking (Draft/Approved/Implemented)

- **Implementation Plan** (`*-plan.md`): Defines the "how"
  - Step-by-step task breakdown
  - File-by-file changes with code snippets
  - Reference to existing patterns to follow
  - Verification steps for each task
  - Required sub-skills and superpowers

**Design Philosophy**:
- Specification-driven: Behavioral contracts in doc comments
- Domain-Driven Design: Model game concepts as value objects
- Object-Oriented: Clear inheritance hierarchies and interfaces
- Registry pattern for extensibility
- Cyclomatic complexity ≤ 5

## Conventions
- File naming: `YYYY-MM-DD-feature-{design|plan}.md`
- Design documents approved before implementation begins
- Implementation plans reference existing code patterns to mirror
- Tasks numbered sequentially with clear verification criteria
- Code examples provided for new abstractions

## Build / Test
None (documentation only)
