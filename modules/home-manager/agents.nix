{
  config,
  lib,
  pkgs,
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

  # Determine if a value is a derivation or a store path string pointing to a directory.
  # Unlike lib.pathIsDirectory, this works at eval time for unbuilt derivations.
  isDerivation = x: x ? type && x.type == "derivation";
  isStorePathString = x: builtins.isString x && lib.hasPrefix builtins.storeDir x;
  isDirLike = x: isDerivation x || (lib.isPath x && lib.pathIsDirectory x) || isStorePathString x;

  normalizeSkill = name: value:
    if builtins.isAttrs value && value ? source
    then value
    else {source = value;};

  resolveTargetDirs = skill: let
    scope = skill.scope or "global";
    scopes =
      if builtins.isList scope
      then scope
      else if scope == "global"
      then ["global"]
      else [scope];
  in
    map (s: toolDirs.${s}) scopes;

  mkSkillFiles = name: rawSkill: let
    skill = normalizeSkill name rawSkill;
    source = skill.source;
    targetDirs = resolveTargetDirs skill;

    fileEntry =
      if isDirLike source
      then {source = source;}
      else if lib.isPath source
      then {source = pkgs.writeTextDir "SKILL.md" (builtins.readFile source);}
      else {source = pkgs.writeTextDir "SKILL.md" source;};
  in
    lib.listToAttrs (
      map (dir:
        lib.nameValuePair "${dir}/${name}" fileEntry)
      targetDirs
    );

  allSkillFiles = lib.foldlAttrs (acc: name: value: acc // mkSkillFiles name value) {} cfg.skills;
in {
  options.programs.agents = {
    enable = mkEnableOption "Declarative agent skills for AI coding tools";

    skills = mkOption {
      type = types.attrsOf (
        types.either
        # Simple form: name = derivation | path | string
        (types.either types.lines (types.either types.path types.package))
        # Full form: name = { source = ...; scope = ...; }
        (types.submodule {
          options = {
            source = mkOption {
              type = types.either types.lines (types.either types.path types.package);
              description = "Skill content (string), path to a file/directory, or a derivation.";
            };
            scope = mkOption {
              type =
                types.either
                (types.enum (["global"] ++ allTools))
                (types.listOf (types.enum (["global"] ++ allTools)));
              default = "global";
              description = ''
                Where to install the skill.

                - `"global"` installs to `~/.agents/skills/` (default)
                - A tool name installs to that tool's skills directory
                - A list of tool names installs to multiple directories

                Available tools: ${lib.concatStringsSep ", " allTools}
              '';
            };
          };
        })
      );
      default = {};
      description = ''
        Agent skills to install for AI coding tools.

        Each attribute name becomes the skill directory name. The value can be:

        - **A string**: inline SKILL.md content, installed globally
        - **A path to a file**: read and written as SKILL.md, installed globally
        - **A path/derivation to a directory**: symlinked as-is, installed globally
        - **An attrset** with `source` and optional `scope` for full control

        Skills are symlinked into the appropriate directories at activation time,
        so derivation outputs don't need to exist during evaluation.
      '';
      example = lib.literalExpression ''
        {
          # Simple: derivation, installed globally
          encoredev-skills = inputs.agent-skills.packages.''${system}.skills-sh.official.encoredev.skills;

          # Simple: inline content, installed globally
          my-custom-skill = '''
            ---
            name: my-skill
            description: Does something useful
            ---
            # My Skill
            Instructions here.
          ''';

          # Full: scoped to specific tools
          private-skill = {
            source = ./skills/private;
            scope = ["claude" "codex"];
          };

          # Full: single tool
          codex-only = {
            source = some-derivation;
            scope = "codex";
          };
        }
      '';
    };
  };

  config = mkIf (cfg.enable && cfg.skills != {}) {
    home.file = allSkillFiles;
  };
}
