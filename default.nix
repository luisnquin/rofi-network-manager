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
      substituteInPlace ./${name}.sh \
        --replace 'DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"' 'DIR=${placeholder "out"}/share'
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin/
      cp ./${name}.sh $out/bin/${name}
      chmod +x $out/bin/${name}

      runHook postInstall
    '';

    postInstall = ''
      wrapProgram ${placeholder "out"}/bin/${name} \
        --prefix PATH : ${lib.makeBinPath propagatedBuildInputs}
    '';
  }
