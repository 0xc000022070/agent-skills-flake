# Agent Skills - Official Registry

A declarative, version-controlled registry of official Agent Skills for Anthropic Claude and related tools. This repository provides a Nix flake for seamless integration into NixOS systems.

## Architecture

### Directory Structure

```
.
├── flake.nix                # Main Nix flake
├── codex.nix                # Home manager integration example
├── lib/
│   ├── systems.nix          # Supported systems list
│   └── packages.nix         # Skill package creation logic
├── sources.json             # Registry of all skills (auto-updated)
├── scripts/
│   ├── update-sources.sh    # Fetch repo metadata from skills.sh
│   └── prefetch-hashes.sh   # Calculate Nix SRI hashes
├── .github/workflows/
│   └── update-sources.yml   # Automated update schedule (every 12h)
└── README.md
```

### sources.json Structure

The `sources.json` file contains the complete registry of all skills, organized by provider and organization:

```json
{
  "version": "1.0",
  "updatedAt": "2026-04-05T12:00:00Z",
  "namespace": "skills-sh",
  "providers": {
    "official": {
      "anthropics": {
        "skills": {
          "owner": "anthropics",
          "repo": "skills",
          "rev": "abc123...",
          "sha256": "sha256-..."
        }
      }
    }
  }
}
```

**Namespace Strategy:**
- `namespace`: Always `skills-sh` (the registry operator)
- `providers.official`: Officially curated skills by Anthropic
- `providers.community` (future): Community-contributed skills from 3rd parties

Each provider can have multiple organizations, which can have multiple repositories.

## Usage

### With Home Manager (Codex Integration)

Use `codex.nix` to integrate agent skills into your home manager configuration:

```bash
# Reference codex.nix for complete examples
cat codex.nix
```

In your home manager configuration:

```nix
{
  inputs.agent-skills.url = "github:anthropics/agent-skills";
}

{
  programs.codex = {
    enable = true;

    skills = with inputs.agent-skills.packages.${system}.skills-sh; {
      # Reference skills from the registry
      claude-code = official.anthropics.claude-code;

      # Define inline skills as markdown
      my-skill = ''
        ---
        name: my-skill
        description: Custom skill
        ---
        # Your markdown content
      '';
    };
  };
}
```

### Direct Nix Flake Usage

Access skills in your own flake:

```nix
{
  inputs = {
    agent-skills.url = "github:anthropics/agent-skills";
  };

  outputs = { agent-skills, ... }: {
    packages.x86_64-linux = {
      my-skills = agent-skills.packages.x86_64-linux.skills-sh-official;
    };
  };
}
```

Available packages:
- `packages.${system}.skills-sh-official` — All official skills
- `packages.${system}.skills-sh.official.anthropics.claude-code` — Specific skill
- `packages.${system}.skills-sh.official.anthropics` — All anthropics repos

## Automation

Runs every 12 hours (0:00 and 12:00 UTC):
1. Fetches organizations and repositories from `skills.sh`
2. Resolves commit SHAs via `git ls-remote`
3. Calculates SRI hashes with `nix-prefetch-github`
4. Commits `sources.json` if changed

**Scripts:**
- `scripts/update-sources.sh` — Fetch metadata (requires: curl, jq, git)
- `scripts/prefetch-hashes.sh` — Calculate hashes (requires: nix-prefetch-github)

## How It Works

1. **sources.json** lists all skill repositories with commit hashes and SRI checksums
2. **flake.nix** reads sources.json and creates Nix packages for each skill
3. **GitHub Actions** updates sources.json automatically every 12 hours
4. **Users** install skills with `nix profile install` or via home manager

## Development

```bash
nix flake develop

# Test flake evaluation
nix flake show

# Manually update registry
scripts/update-sources.sh
scripts/prefetch-hashes.sh

# View available packages
nix flake show --json | jq '.packages'
```

## Design

**JSON Registry:** Language-agnostic, auditable, cacheable
**Nix Flakes:** Reproducible builds, declarative, multi-system
**Namespaced:** Supports official, community, and custom providers
**12-Hour Updates:** Balances freshness with CI efficiency

## Contributing

To contribute skills:
- Submit to [Anthropic's official channels](https://github.com/anthropics)
- Once merged, appears in registry within 12 hours

To extend for community providers:
1. Update `sources.json` structure
2. Modify `lib/packages.nix` as needed
3. Workflow automatically fetches and hashes

## License

This registry and tooling are provided under the same license as the individual skill repositories.

---

**Last Updated:** See `sources.json` `updatedAt` field
**Registry Source:** https://skills.sh
