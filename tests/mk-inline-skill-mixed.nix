{agentic-flake, ...}: let
  # Filesystem-based skills
  fsSkills = agentic-flake.lib.mkSkill {
    src = ./fixtures/mk-skill;
  };

  # Inline skills
  inlineSkills = agentic-flake.lib.mkInlineSkill {
    "quick-tips" = {
      description = "Quick helpful tips";
      content = "# Quick Tips\n\nSome quick hints.";
    };

    "docs/reference" = {
      name = "reference";
      description = "Documentation reference";
      content = "# Reference\n\nRef docs here.";
    };
  };
in {
  homeModule = {
    imports = [agentic-flake.homeModules.default];

    programs.agents = {
      enable = true;

      skills = [
        # Mix filesystem and inline skills
        (fsSkills {
          scopes = ["global"];
          plugins = ["root-skill"];
          prefix = "fs-";
        })

        (inlineSkills {
          scopes = ["global"];
          plugins = ["quick-tips" "docs/reference"];
          prefix = "inline-";
        })
      ];
    };
  };

  testScript = ''
    # Test filesystem skill with prefix
    machine.succeed("test -d /home/testuser/.agents/skills/fs-root-skill")
    machine.succeed("test -f /home/testuser/.agents/skills/fs-root-skill/SKILL.md")
    machine.succeed("grep -q 'Root Skill' /home/testuser/.agents/skills/fs-root-skill/SKILL.md")

    # Test inline skill 1
    machine.succeed("test -d /home/testuser/.agents/skills/inline-quick-tips")
    machine.succeed("test -f /home/testuser/.agents/skills/inline-quick-tips/SKILL.md")
    machine.succeed("grep -q 'name: quick-tips' /home/testuser/.agents/skills/inline-quick-tips/SKILL.md")
    machine.succeed("grep -q 'description: Quick helpful tips' /home/testuser/.agents/skills/inline-quick-tips/SKILL.md")
    machine.succeed("grep -q '# Quick Tips' /home/testuser/.agents/skills/inline-quick-tips/SKILL.md")

    # Test inline skill 2 (nested with explicit name)
    machine.succeed("test -d /home/testuser/.agents/skills/inline-docs/reference")
    machine.succeed("test -f /home/testuser/.agents/skills/inline-docs/reference/SKILL.md")
    machine.succeed("grep -q 'name: reference' /home/testuser/.agents/skills/inline-docs/reference/SKILL.md")
    machine.succeed("grep -q 'description: Documentation reference' /home/testuser/.agents/skills/inline-docs/reference/SKILL.md")
    machine.succeed("grep -q '# Reference' /home/testuser/.agents/skills/inline-docs/reference/SKILL.md")

    # Verify filesystem skill content is preserved (original SKILL.md from fixture)
    machine.succeed("test ! -d /home/testuser/.agents/skills/root-skill")
    machine.succeed("test ! -d /home/testuser/.agents/skills/quick-tips")
  '';
}
