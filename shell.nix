with import <nixpkgs> { };

mkShell {
    nativeBuildInputs = [
        zig_0_11
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
