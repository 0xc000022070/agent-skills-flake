{
  description = "Codex with Agent Skills Integration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agent-skills.url = "github:anthropics/agent-skills";
  };

  outputs = { self, nixpkgs, home-manager, agent-skills }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;

      skillsInput = agent-skills.packages.${system}.skills-sh.official;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [ pkgs.codex ];

        shellHook = ''
          echo "Codex environment loaded with agent skills"
        '';
      };

      homeConfigurations.example = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          {
            home = {
              username = "user";
              homeDirectory = "/home/user";
              stateVersion = "24.05";
            };

            programs.codex = {
              enable = true;

              settings = {
                model = "gpt-4";
                model_provider = "openai";
              };

              skills = {
                # Reference skills from official registry
                claude-code = skillsInput.anthropics.claude-code;
                skills = skillsInput.anthropics.skills;

                # Define inline skills
                custom-skill = ''
                  ---
                  name: custom-skill
                  description: Custom skill for this project
                  ---

                  # Custom Skill

                  Your markdown content here.
                '';
              };
            };
          }
        ];
      };
    };
}
