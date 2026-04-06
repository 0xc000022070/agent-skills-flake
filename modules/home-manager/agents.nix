{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types;

  cfg = config.programs.agents;

  toolDirs = {
    global = ".agents/skills";
    codex = ".codex/skills";
    gemini = ".gemini/skills";
    claude = ".claude/skills";
    opencode = ".config/opencode/skills";
  };

  allTools = lib.attrNames (lib.removeAttrs toolDirs ["global"]);

  scopeToDirs = scopes: let
    normalized =
      if builtins.isList scopes
      then scopes
      else [scopes];
  in
    map (s: toolDirs.${s}) normalized;

  mkConfiguredSkillFiles = entry: let
    drv = entry.drv;
    plugins = entry.plugins;
    scopes = entry.scopes or ["global"];
    prefix = entry.prefix or "";
    dirs = scopeToDirs scopes;
  in
    lib.listToAttrs (lib.flatten (
      map (plugin:
        map (dir:
          lib.nameValuePair "${dir}/${prefix}${plugin}" {
            source = "${drv}/${plugin}";
          })
        dirs)
      plugins
    ));

  isConfiguredEntry = x: builtins.isAttrs x && x ? drv && x ? plugins;

  allSkillFiles = lib.foldl' (acc: entry: acc // mkConfiguredSkillFiles entry) {} cfg.skills;
in {
  options.programs.agents = {
    enable = mkEnableOption "Declarative agent skills for AI coding tools";

    skills = mkOption {
      type = types.listOf types.raw;
      default = [];
      description = ''
        List of configured skill entries to install.

        Each entry is created by calling a skill package as a function:

        ```nix
        official.encoredev.skills {
          plugins = ["encore-api" "encore-database"];
          scopes = ["global" "claude"];  # optional, default: ["global"]
          prefix = "";                   # optional, default: ""
        }
        ```

        - `plugins`: list of skill names to install from the package
        - `scopes`: where to install — `"global"` (~/.agents/skills/),
          or tool-specific: ${lib.concatStringsSep ", " (map (t: ''"${t}"'') allTools)}
        - `prefix`: string prepended to each skill directory name (to avoid conflicts)

        Skills are symlinked at activation time into each scope directory as:
        `<scope-dir>/<prefix><plugin-name>/` → `<store-path>/<plugin-name>/`
      '';
      example = lib.literalExpression ''
        with pkgs.agent-skills.skills-sh; [
          (official.encoredev.skills {
            plugins = [
              "encore-api"
              "encore-auth"
              "encore-database"
              "encore-service"
              "encore-testing"
              "encore-code-review"
            ];
            scopes = ["global" "claude"];
          })

          (official.anthropics.claude-code {
            plugins = [
              "claude-api"
              "pdf"
              "docx"
              "xlsx"
              "pptx"
            ];
          })

          (official.anthropics.claude-code {
            plugins = ["mcp-builder"];
            scopes = ["codex"];
            prefix = "anthropic-";
          })
        ]
      '';
    };
  };

  config = mkIf (cfg.enable && cfg.skills != []) {
    assertions =
      map (entry: {
        assertion = isConfiguredEntry entry;
        message = ''
          programs.agents.skills expects configured entries.
          Call the skill package as a function:
            official.encoredev.skills { plugins = ["encore-api"]; }
        '';
      })
      cfg.skills;

    home.file = allSkillFiles;
  };
}
