# Contributing

Thank you for contributing to QdrantClient.jl.

## Development Setup

1. Install Julia 1.12+.
2. Clone the repository.
3. Start a local Qdrant instance on ports 6333/6334.
4. Run tests:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

## Pull Request Guidelines

- Keep changes focused and small.
- Add or update tests for behavior changes.
- Update docs and README when public API changes.
- Ensure CI passes on all supported platforms.

## Coding Guidelines

- Preserve API consistency and response typing patterns.
- Prefer explicit parsing helpers for typed responses.
- Use defensive parsing for dynamic API payloads.
