{
  description = "Crimsonlink";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { nixpkgs, ... }: 
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    staticSDL2 = pkgs.SDL2.overrideAttrs (old: { dontDisableStatic = true; });
    dependencies = with pkgs; [
        libGL
        libGLU
        staticSDL2
        SDL2_ttf
        SDL2_gfx
        SDL2_image
    ];
  in
  {
      packages.x86_64-linux.default = pkgs.stdenv.mkDerivation {
          pname = "Crimsonlink";
          version = "0.1.0";

          src = ./.;

          nativeBuildInputs = [
              pkgs.zig
          ];

          buildInputs = dependencies;

          doCheck = true;

          XDG_CACHE_HOME = "xdg_cache";

          buildPhase = ''
              zig build
          '';

          installPhase = ''
              mkdir -p $out/bin
              cp zig-out/bin/Crimsonlink $out/bin
          '';
      };

      devShells.x86_64-linux.default = pkgs.mkShell {
          buildInputs = dependencies;
      };
  };
}
