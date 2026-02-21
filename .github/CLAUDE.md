# Directory Overview

## Purpose
Contains project documentation and AI assistant configuration files for GitHub Copilot and other development tools.

## Key Files
- **copilot-instructions.md**: Comprehensive development guidelines, architectural patterns, and project conventions for Wordatro (418 lines)
- **game-configuration.md**: Core game parameters, constants, and configuration values (board size, animations, modifiers, etc.)

## Public Interfaces
N/A - Documentation directory with no exported modules.

## Dependencies
None - standalone documentation files.

## Architecture / Patterns
- **Documentation as Code**: Development principles and game configuration co-located with codebase
- **Single Source of Truth**: copilot-instructions.md serves as comprehensive reference for:
  - Development principles (Godot-First, Learning >> Doing)
  - Architecture patterns (Composition, Atomic State, Strategy)
  - Core components and signal flow
  - Tile lifecycle and atomic cell binding
  - Game progression and level structure

## Conventions
- **File Naming**: kebab-case for documentation files
- **Markdown Format**: Standard GitHub-flavored markdown
- **Structure**: 
  - copilot-instructions.md: Project overview → Principles → Architecture → Patterns → Tasks → Roadmap
  - game-configuration.md: Categorized by system (Board, Gameplay, UI, Animation, Modifiers)
- **Maintenance**: Update when architectural decisions or game constants change

## Build / Test
N/A - Documentation files do not require building or testing.
