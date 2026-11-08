cmake -S . -B build86 -A x64 -DCMAKE_PREFIX_PATH=./ThirdParty/SDL3
cmake --build build --config Release
pause