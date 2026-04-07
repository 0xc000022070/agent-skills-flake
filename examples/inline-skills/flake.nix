{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agentic-flake.url = "path:../..";
  };

  outputs = {
    nixpkgs,
    home-manager,
    agentic-flake,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    # Define inline skills with structured metadata
    utilitySkills = agentic-flake.lib.mkInlineSkill {
      "quick-reference" = {
        description = "Quick reference for common commands and patterns";
        tags = ["reference" "quick"];
        content = ''
          # Quick Reference

          Provides instant lookup for:
          - Common shell commands
          - Git workflows
          - CLI tool syntax
          - Configuration examples

          Just ask for what you need and I'll provide the syntax.
        '';
      };

      "code-formatter" = {
        description = "Format and beautify code snippets";
        tags = ["formatting" "utility"];
        content = ''
          # Code Formatter

          Handles formatting for:
          - JSON, YAML, TOML
          - Markdown tables and code blocks
          - Shell scripts
          - Multi-language code cleanup

          Paste your code and request formatting or beautification.
        '';
      };

      "docs/generator" = {
        name = "doc-generator";
        description = "Generate documentation from code and specifications";
        tags = ["documentation" "generator"];
        content = ''
          # Documentation Generator

          Creates:
          - README files from specifications
          - API documentation
          - Architecture diagrams in text form
          - Changelog entries

          Provide code samples or specifications for documentation.
        '';
      };

      "testing/helper" = {
        name = "test-helper";
        description = "Test case generation and validation";
        tags = ["testing" "quality"];
        content = ''
          # Test Helper

          Assists with:
          - Unit test generation
          - Test case edge case identification
          - Mock data creation
          - Test coverage analysis

          Share your function signature or spec for test generation.
        '';
      };
    };
  in {
    homeConfigurations.dev = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      modules = [
        agentic-flake.homeModules.default
        {
          home.username = "dev";
          home.homeDirectory = "/home/dev";
          home.stateVersion = "26.05";

          programs.agents = {
            enable = true;

            # Install inline utility skills globally
            skills = [
              (utilitySkills {
                scopes = ["global"];
                plugins = [
                  "quick-reference"
                  "code-formatter"
                  "docs/generator"
                  "testing/helper"
                ];
                prefix = "util-";
              })
            ];
          };
        }
      ];
    };
  };
}
