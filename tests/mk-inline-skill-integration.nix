{agentic-flake, ...}: let
  inlineSkills = agentic-flake.lib.mkInlineSkill {
    "global-skill" = {
      description = "Available globally";
      tags = ["global"];
      content = "# Global Skill\n\nAvailable everywhere.";
    };

    "project/helper" = {
      name = "project-helper";
      description = "Helper for projects";
      tags = ["project" "helper"];
      content = "# Project Helper\n\nHelps with project tasks.";
    };
  };
in {
  homeModule = {
    imports = [agentic-flake.homeModules.default];

    programs.agents = {
      enable = true;

      workspaces.demo = {
        path = "Projects/demo";
        scopes = ["claude"];
      };

      skills = [
        (inlineSkills {
          scopes = ["global"];
          plugins = ["global-skill"];
        })

        (inlineSkills {
          scopes = ["demo"];
          plugins = ["project/helper"];
          prefix = "inline-";
        })
      ];
    };
  };

  testScript = ''
    # Test 1: Global skill installed to global scope
    machine.succeed("test -d /home/testuser/.agents/skills/global-skill")
    machine.succeed("test -f /home/testuser/.agents/skills/global-skill/SKILL.md")

    # Test 2: Verify SKILL.md contains frontmatter
    machine.succeed("grep -q 'name: global-skill' /home/testuser/.agents/skills/global-skill/SKILL.md")
    machine.succeed("grep -q 'description: Available globally' /home/testuser/.agents/skills/global-skill/SKILL.md")
    machine.succeed("grep -q 'tags:' /home/testuser/.agents/skills/global-skill/SKILL.md")

    # Test 3: Verify SKILL.md contains content body
    machine.succeed("grep -q '# Global Skill' /home/testuser/.agents/skills/global-skill/SKILL.md")
    machine.succeed("grep -q 'Available everywhere' /home/testuser/.agents/skills/global-skill/SKILL.md")

    # Test 4: Project-scoped skill with prefix
    machine.succeed("test -d /home/testuser/Projects/demo/.claude/skills/inline-project/helper")
    machine.succeed("test -f /home/testuser/Projects/demo/.claude/skills/inline-project/helper/SKILL.md")

    # Test 5: Verify nested skill frontmatter uses explicit name
    machine.succeed("grep -q 'name: project-helper' /home/testuser/Projects/demo/.claude/skills/inline-project/helper/SKILL.md")
    machine.succeed("grep -q 'description: Helper for projects' /home/testuser/Projects/demo/.claude/skills/inline-project/helper/SKILL.md")

    # Test 6: Verify nested skill content
    machine.succeed("grep -q '# Project Helper' /home/testuser/Projects/demo/.claude/skills/inline-project/helper/SKILL.md")

    # Test 7: Verify frontmatter is properly formatted
    machine.succeed("head -1 /home/testuser/.agents/skills/global-skill/SKILL.md | grep -q '^---$'")
    machine.succeed("grep '^---$' /home/testuser/.agents/skills/global-skill/SKILL.md | wc -l | grep -q 2")

    # Test 8: Verify skills are in the right scopes only
    machine.fail("test -d /home/testuser/.claude/skills/global-skill")
    machine.fail("test -d /home/testuser/.agents/skills/inline-project")
  '';
}
