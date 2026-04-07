# Inline Skills Example

This example demonstrates how to define and use **inline skills** — skills declared directly in Nix with structured metadata, without filesystem discovery.

## What are Inline Skills?

Inline skills let you create lightweight, focused skills quickly without maintaining directory structures. Perfect for:
- Utility functions (quick reference, formatters, helpers)
- Project-specific tools
- Dynamic skill generation
- Rapid prototyping

## Example Skills

This example defines 4 utility skills:

1. **quick-reference** — Command and pattern lookup
2. **code-formatter** — Code beautification and formatting
3. **docs/generator** — Documentation generation (nested path)
4. **testing/helper** — Test case and mock generation

## Usage

Each skill is defined with:

```nix
"skill-id" = {
  name = "optional-name";           # Defaults to skill-id if omitted
  description = "What it does";     # Shown in `gemini skills list`
  tags = ["category" "tags"];       # Organize and discover skills
  content = "# Markdown body\n..."; # Skill documentation
};
```

When called via `gemini`, inline skills behave identically to filesystem skills:

```bash
$ gemini skills list
util-quick-reference [Enabled]
  Description: Quick reference for common commands and patterns
  Location:    /home/dev/.agents/skills/util-quick-reference/SKILL.md

util-code-formatter [Enabled]
  Description: Format and beautify code snippets
  Location:    /home/dev/.agents/skills/util-code-formatter/SKILL.md

util-docs/generator [Enabled]
  Description: Generate documentation from code and specifications
  Location:    /home/dev/.agents/skills/util-docs/generator/SKILL.md

util-testing/helper [Enabled]
  Description: Test case generation and validation
  Location:    /home/dev/.agents/skills/util-testing/helper/SKILL.md
```

## Key Features

✓ **Structured metadata** — name, description, tags all in Nix
✓ **Markdown content** — Keep documentation clean and readable
✓ **Prefix support** — All skills get `util-` prefix to avoid conflicts
✓ **Nested paths** — `docs/generator` creates nested directory structure
✓ **Composable** — Mix with filesystem skills using same API
✓ **Home-manager integration** — Full integration with home-manager

## Files Generated

Once installed via home-manager, inline skills create proper SKILL.md files:

```
~/.agents/skills/
├── util-quick-reference/
│   └── SKILL.md
├── util-code-formatter/
│   └── SKILL.md
├── util-docs/
│   └── generator/
│       └── SKILL.md
└── util-testing/
    └── helper/
        └── SKILL.md
```

Each SKILL.md contains proper YAML frontmatter plus markdown body.

## Advantages over Filesystem Skills

| Aspect | Filesystem Skills | Inline Skills |
|--------|-------------------|---------------|
| File management | Separate directory tree | Single Nix file |
| Quick changes | Edit files | Edit Nix config |
| Metadata | In SKILL.md YAML | Nix attributes |
| Setup burden | Maintain structure | Just define table |
| Sharing config | Repository required | Flake.nix |

## API

```nix
inlineSkills = agentic-flake.lib.mkInlineSkill {
  "skill-id" = { description, tags?, content };
  "nested/path/skill" = { name?, description, tags?, content };
};

# Call with config (same as mkSkill):
(inlineSkills {
  plugins = ["skill-id" "nested/path/skill"];
  scopes = ["global"];        # or ["claude"], ["workspace-name"], etc.
  prefix = "util-";           # prepended to all skill names
})
```

## Testing

All inline skills pass:
- Unit tests (metadata generation, frontmatter)
- Integration tests (home-manager materialization)
- Composition tests (mixing with filesystem skills)

See `tests/mk-inline-skill-*.nix` for test implementations.
