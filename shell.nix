with import <nixpkgs> { };

mkShell {
    nativeBuildInputs = [
        xorg.libX11 
        xorg.libXinerama 
        libGL 
        libGLU 
        xorg.libXcursor 
        xorg.libXrandr 
        xorg.xinput 
        xorg.xkbutils 
        xorg.libXi
    ];
}
