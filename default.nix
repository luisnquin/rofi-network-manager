{pkgs ? import <nixpkgs> {}}:
with pkgs;
  stdenv.mkDerivation rec {
    name = "rofi-network-manager";

    src = builtins.path {
      inherit name;
      path = ./.;
    };

    nativeBuildInputs = [
      makeWrapper
    ];

    propagatedBuildInputs = [
      networkmanager
      qrencode
      dunst
      rofi
    ];

    postPatch = ''
      substituteInPlace ./${name}.bash \
        --replace 'DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"' 'DIR=${placeholder "out"}/share'

      substituteInPlace ./${name}.bash \
        --replace 'ICONS_DIR="$PWD/assets/icons"' 'ICONS_DIR=${placeholder "out"}/share/icons'
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/icons
      cp ./assets/icons/* $out/share/icons

      mkdir -p $out/bin
      cp ./${name}.bash $out/bin/${name}
      chmod +x $out/bin/${name}

      runHook postInstall
    '';

    postInstall = ''
      wrapProgram ${placeholder "out"}/bin/${name} \
        --prefix PATH : ${lib.makeBinPath propagatedBuildInputs}
    '';
  }
