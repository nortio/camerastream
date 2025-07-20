{
  pkgs ? import <nixpkgs> { },
  unstable ? import <nixos-unstable> { },
}:
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    pkg-config
    cmake
    libpulseaudio
    alsa-lib
    # ninja
    #clang-tools must be inserted before clang https://github.com/NixOS/nixpkgs/issues/76486
    llvmPackages_20.clang-tools
    llvmPackages_20.clang
    gcc15
    ninja
    cppcheck
    unstable.tracy
  ];
  buildInputs = with pkgs; [
    #libglvnd.dev
    xorg.libX11.dev
    #xorg.libXi.dev
    #xorg.libXcursor.dev
    #protobufc
    openssl.dev
    #protobuf_25
    zlib.dev
    #abseil-cpp
    libjpeg.dev
  ];
  LD_LIBRARY_PATH = [ "${pkgs.libpulseaudio}/lib:${pkgs.alsa-lib}/lib" ];
}
