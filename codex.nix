{
  description = "Codex with Agent Skills Integration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
  }: let
    system = "x86_64-linux";
  in {
    homeConfigurations.example = home-manager.lib.homeManagerConfiguration {
      modules = [
        {
          programs.codex = {
            enable = true;

            settings = {
              model = "gpt-4";
              model_provider = "openai";
            };

            skills = with self.packages.${system}.skills-sh.official; {
              # Reference skills from official registry
              claude-code = anthropics.claude-code;
              skills = anthropics.skills;

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
