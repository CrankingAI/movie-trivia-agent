# .github/copilot-instructions.md

## Commit Messages

Always use a Conventional Commits prefix:
```
<type>: <description>
```

For more than one commit or type, combine them into most impactful.

### Type Selection

1. If the change is breaking, append "!" (e.g., `feat!:`, `fix!:`)
2. If it adds new functionality, use `feat`
3. If it fixes a bug, refactors, or improves performance, use `fix`
4. Otherwise, use `chore`