cmake -S . -B build86 -A Win32 -DCMAKE_PREFIX_PATH=./ThirdParty/SDL3
cmake --build build86 --config Release
pause