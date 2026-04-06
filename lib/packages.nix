{
  pkgs,
  lib,
}: {
  mkSkillPackage = {
    owner,
    repo,
    rev,
    sha256,
  }:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "${owner}-${repo}";
      version = rev;

      src =
        if sha256 != ""
        then pkgs.fetchFromGitHub {inherit owner repo rev sha256;}
        else
          pkgs.fetchGit {
            url = "https://github.com/${owner}/${repo}";
            inherit rev;
          };

      dontBuild = true;
      dontConfigure = true;

      installPhase = ''
        mkdir -p $out

        cp {AGENTS.md,CLAUDE.md} "$out/" || true

        if [ -d "plugins" ]; then
          find plugins -mindepth 1 -maxdepth 1 -type d | while read plugin_dir; do
            if [ -d "$plugin_dir/skills" ]; then
              # Copy each skill directory with all contents, dereferencing symlinks
              find "$plugin_dir/skills" -mindepth 1 -maxdepth 1 -type d | while read skill_dir; do
                skill_name=$(basename "$skill_dir")
                cp -rL "$skill_dir" "$out/$skill_name"
              done
            fi
          done
        fi
      '';

      meta = with lib; {
        description = "Agent skill: ${owner}/${repo}";
        homepage = "https://github.com/${owner}/${repo}";
        license = licenses.free;
        platforms = platforms.all;
      };
    };

  buildPackageTree = mkSkill: providers:
    lib.mapAttrs (
      providerName: providerData:
        lib.mapAttrs (
          org: orgRepos:
            lib.mapAttrs (
              repoName: repoData:
                mkSkill repoData
            )
            orgRepos
        )
        providerData
    )
    providers;

  mkOfficialAlias = pkgs: lib: flattenedPackages:
    pkgs.symlinkJoin {
      name = "skills-sh-official";
      paths = lib.flatten (
        lib.mapAttrsToList (
          org: orgRepos:
            lib.mapAttrsToList (repoName: package: package) orgRepos
        )
        flattenedPackages.official
      );
      postBuild = ''
        mkdir -p $out/share/doc
        echo "Official Agent Skills Collection" > $out/share/doc/README.md
      '';
    };
}
