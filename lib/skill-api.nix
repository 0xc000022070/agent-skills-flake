{lib}: let
  normalizeSrc = src:
    if builtins.typeOf src == "path"
    then src
    else let
      coerced = builtins.tryEval (toString src);
    in
      if coerced.success
      then /. + builtins.unsafeDiscardStringContext coerced.value
      else throw "mkSkill expects `src` to be a path-like value such as `./.` or `builtins.fetchGit { ...; }`";

  rootSkillName = src: let
    parts = lib.filter (part: part != "") (lib.splitString "/" (toString src));
  in
    if parts == []
    then throw "mkSkill could not derive a root skill name from src"
    else lib.last parts;

  isTemplate = relParts: lib.any (part: builtins.match ".*[Tt]emplate.*" part != null) relParts;

  discoverSkills = src: let
    normalizedSrc = normalizeSrc src;

    # Recursively scan directory tree for SKILL.md files, building (skillId -> relPath) map.
    # Skips directories matching template patterns and respects symlinks.
    scan = path: relParts: let
      entries = builtins.readDir path;
      relPath = lib.concatStringsSep "/" relParts;
      hasSkill = entries ? "SKILL.md";
      isTemplatePath = isTemplate relParts;

      current =
        if hasSkill && !isTemplatePath
        then let
          skillId =
            if relPath == ""
            then rootSkillName normalizedSrc
            else relPath;
        in [
          {
            name = skillId;
            value =
              if relPath == ""
              then "."
              else relPath;
          }
        ]
        else [];

      dirs = builtins.attrNames (lib.filterAttrs (name: kind: kind == "directory" || kind == "symlink") entries);

      deeper = lib.flatten (map (name: scan (path + "/${name}") (relParts ++ [name])) dirs);
    in
      current ++ deeper;

    discovered = lib.listToAttrs (scan normalizedSrc []);
  in
    if discovered == {}
    then throw "mkSkill found no SKILL.md files under ${toString normalizedSrc}. Ensure skill directories contain SKILL.md and are not in 'template' directories."
    else discovered;

  assertKnownPlugins = availablePlugins: requestedPlugins: let
    unknown = lib.filter (plugin: !(builtins.elem plugin availablePlugins)) requestedPlugins;
  in
    if unknown != []
    then
      throw ''
        Unknown skill plugin(s): ${lib.concatStringsSep ", " unknown}
        Available plugins: ${lib.concatStringsSep ", " availablePlugins}
      ''
    else true;

  mkConfiguredSkillEntry = {
    src,
    skillMap,
  }: let
    availablePlugins = builtins.attrNames skillMap;
  in {
    inherit src skillMap availablePlugins;
    __agenticSkill = true;

    __functor = _self: {
      plugins,
      scopes ? ["global"],
      prefix ? "",
    }:
      builtins.seq (assertKnownPlugins availablePlugins plugins) {
        inherit plugins scopes prefix src skillMap availablePlugins;
        __agenticSkill = true;
      };
  };
in {
  inherit normalizeSrc discoverSkills assertKnownPlugins;

  mkSkill = {src}:
    mkConfiguredSkillEntry {
      inherit src;
      skillMap = discoverSkills src;
    };
}
