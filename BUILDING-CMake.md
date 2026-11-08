# Building with CMake (Windows, MSVC)

Prerequisites: Visual Studio 2022 (C++ + MASM), CMake >= 3.24, Git (optional, for version info),
and an SDL3 development package (official "SDL3-devel-*-VC" zip or vcpkg `sdl3`).

    cmake -S . -B build -G "Visual Studio 17 2022" -A x64 -DCMAKE_PREFIX_PATH=C:/path/to/SDL3
    cmake --build build --config Release
    ctest --test-dir build -C Release        # if XIDI_BUILD_TESTS=ON

Use `-A Win32` in a separate build dir for the 32-bit binaries.
Options: XIDI_BUILD_TESTS, XIDI_BUILD_FORWARDERS, XIDI_BUILD_HOOK_MODULE, XIDI_WARNINGS_AS_ERRORS.

Notes:
- SDL3 sources are not in the archive (only headers); SDL.vcxproj is not ported. SDL3.dll must sit beside Xidi.<arch>.dll at runtime unless SDL3 is built static.
- Modules/Infra is a git submodule in the original repo (its .git file points to ../../.git/modules/Infra).
