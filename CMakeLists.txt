# Xidi (SDL3 backend) - CMake build
# Windows-only (MSVC or clang-cl). Generated from the Visual Studio projects.
cmake_minimum_required(VERSION 3.24)
project(Xidi LANGUAGES C CXX ASM_MASM RC)

if(NOT WIN32)
  message(FATAL_ERROR "Xidi targets Windows only.")
endif()

option(XIDI_BUILD_TESTS        "Build the XidiTest and Infra test executables" ON)
option(XIDI_BUILD_FORWARDERS   "Build dinput.dll, dinput8.dll and winmm.dll forwarders" ON)
option(XIDI_BUILD_HOOK_MODULE  "Build the Hookshot hook module" ON)
option(XIDI_SDL3_STATIC          "Link SDL3 statically instead of using SDL3.dll" OFF)
option(XIDI_WARNINGS_AS_ERRORS "Treat warnings as errors (matches the VS projects)" ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
# Static CRT in every configuration (/MT, and /MTd in Debug)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# ---- SDL3 -------------------------------------------------------------------
# Configured BEFORE the project-wide warning/definition flags below, so /WX etc. do not apply to SDL itself.
# 1) If a full SDL3 source tree is in ThirdParty/SDL3 (or ThirdParty/SDL3/Files), build it from source.
# 2) Otherwise use an installed SDL3 package via CMAKE_PREFIX_PATH / SDL3_DIR.
# Choose with -DXIDI_SDL3_MODE=AUTO|SOURCE|PACKAGE (AUTO = source tree if present, else package).
set(XIDI_SDL3_MODE "AUTO" CACHE STRING "Where SDL3 comes from: AUTO, SOURCE (ThirdParty/SDL3) or PACKAGE (installed, e.g. SDL3-VC)")
set_property(CACHE XIDI_SDL3_MODE PROPERTY STRINGS AUTO SOURCE PACKAGE)
set(XIDI_SDL3_SOURCE_DIR "")
set(XIDI_SDL3_INCLUDE_DIRS "")
if(NOT XIDI_SDL3_MODE STREQUAL "PACKAGE")
  foreach(_dir "${CMAKE_SOURCE_DIR}/ThirdParty/SDL3" "${CMAKE_SOURCE_DIR}/ThirdParty/SDL3/Files")
    if(EXISTS "${_dir}/CMakeLists.txt" AND EXISTS "${_dir}/include/SDL3/SDL.h")
      set(XIDI_SDL3_SOURCE_DIR "${_dir}")
      break()
    endif()
  endforeach()
endif()
if(XIDI_SDL3_MODE STREQUAL "SOURCE" AND NOT XIDI_SDL3_SOURCE_DIR)
  message(FATAL_ERROR "XIDI_SDL3_MODE=SOURCE but no SDL3 source tree (CMakeLists.txt + include/SDL3/SDL.h) found in ThirdParty/SDL3")
endif()
if(XIDI_SDL3_SOURCE_DIR)
  message(STATUS "Building SDL3 from source: ${XIDI_SDL3_SOURCE_DIR}")
  if(XIDI_SDL3_STATIC)
    set(SDL_SHARED     OFF CACHE BOOL "" FORCE)
    set(SDL_STATIC     ON  CACHE BOOL "" FORCE)
  else()
    set(SDL_SHARED     ON  CACHE BOOL "" FORCE)
    set(SDL_STATIC     OFF CACHE BOOL "" FORCE)
  endif()
  set(SDL_TESTS        OFF CACHE BOOL "" FORCE)
  set(SDL_EXAMPLES     OFF CACHE BOOL "" FORCE)
  set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
  set(SDL_INSTALL      OFF CACHE BOOL "" FORCE)
  add_subdirectory("${XIDI_SDL3_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/SDL3")
  # Allow both <SDL3/SDL.h> and a bare <SDL.h> in the Xidi sources
  set(XIDI_SDL3_INCLUDE_DIRS "${XIDI_SDL3_SOURCE_DIR}/include" "${XIDI_SDL3_SOURCE_DIR}/include/SDL3")
else()
  message(STATUS "No SDL3 source tree in ThirdParty; looking for an installed SDL3 package")
  find_package(SDL3 CONFIG REQUIRED)
endif()

# Which SDL3 target to link
if(XIDI_SDL3_STATIC AND TARGET SDL3::SDL3-static)
  set(XIDI_SDL3_TARGET SDL3::SDL3-static)
else()
  if(XIDI_SDL3_STATIC)
    message(WARNING "XIDI_SDL3_STATIC requested but no static SDL3 target is available; using the shared library")
  endif()
  set(XIDI_SDL3_TARGET SDL3::SDL3)
endif()

# VS projects use stdcpplatest
# One flag per generator expression: the VS generator mis-parses "/MP" when it shares one with other flags.
add_compile_options($<$<COMPILE_LANGUAGE:CXX>:/std:c++latest>)
add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/W3>)
add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/MP>)
if(XIDI_WARNINGS_AS_ERRORS)
  add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/WX>)
endif()
add_compile_definitions(_UNICODE UNICODE)

# Architecture suffix used in output names, e.g. Xidi.64.dll
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
  set(XIDI_ARCH 64)
else()
  set(XIDI_ARCH 32)
endif()

include(GitVersionInfo)   # generates GitVersionInfo.generated.h

# ---- Third-party ----------------------------------------------------------
# SDL3 is configured near the top of this file (before the project-wide compile flags).

add_library(Xidi_Boost INTERFACE)
target_include_directories(Xidi_Boost SYSTEM INTERFACE ThirdParty/Boost/Files)
add_library(Xidi_XstdBitSet INTERFACE)
target_include_directories(Xidi_XstdBitSet SYSTEM INTERFACE ThirdParty/XstdBitSet/Files/include)
add_library(Xidi_Hookshot INTERFACE)
target_include_directories(Xidi_Hookshot SYSTEM INTERFACE ThirdParty/Hookshot/Files/Include)

# ---- Infra module -----------------------------------------------------------
add_subdirectory(Modules/Infra)

# ---- Xidi common settings ---------------------------------------------------
function(xidi_common target)
  target_include_directories(${target} PRIVATE
    ${CMAKE_SOURCE_DIR}/Include/Xidi
    ${CMAKE_SOURCE_DIR}/Include/Xidi/Internal
    ${XIDI_GENERATED_DIR})
  target_link_libraries(${target} PRIVATE Infra::Core)
  # Resource header is force-included by the VS build
  target_compile_options(${target} PRIVATE $<$<COMPILE_LANGUAGE:CXX>:/FI${CMAKE_SOURCE_DIR}/Resources/Xidi.h>)
  if(NOT target STREQUAL "Xidi")
    target_compile_options(${target} PRIVATE $<$<COMPILE_LANGUAGE:CXX>:/FI${CMAKE_SOURCE_DIR}/Resources/${target}.h>)
  endif()
  add_dependencies(${target} xidi_git_version)
endfunction()

# ---- Xidi.dll (main implementation) -------------------------------------------
set(XIDI_MAIN_SOURCES
    Source/ApiDirectInput.cpp
    Source/ApiGUID.cpp
    Source/ApiXidi.cpp
    Source/ApiXidiImportFunctions2.cpp
    Source/ApiXidiMetadata.cpp
    Source/ControllerIdentification.cpp
    Source/ControllerMath.cpp
    Source/DataFormat.cpp
    Source/DirectInputClassFactory.cpp
    Source/DllFunctions.cpp
    Source/DllMain.cpp
    Source/ElementMapper.cpp
    Source/ExportApiDirectInput.cpp
    Source/ForceFeedbackDevice.cpp
    Source/ForceFeedbackEffect.cpp
    Source/ForceFeedbackParameters.cpp
    Source/Globals.cpp
    Source/ImportApiDirectInput.cpp
    Source/ImportApiWinMM.cpp
    Source/ImportApiXInput.cpp
    Source/Keyboard.cpp
    Source/Mapper.cpp
    Source/MapperBuilder.cpp
    Source/MapperDefinitions.cpp
    Source/MapperParser.cpp
    Source/Mouse.cpp
    Source/PhysicalController.cpp
    Source/PhysicalControllerBackendSDL3.cpp
    Source/PluginRegistry.cpp
    Source/StateChangeEventBuffer.cpp
    Source/Strings.cpp
    Source/VirtualController.cpp
    Source/VirtualDirectInputDevice.cpp
    Source/VirtualDirectInputEffect.cpp
    Source/WrapperIDirectInput.cpp
    Source/WrapperJoyWinMM.cpp
    Source/XidiConfigReader.cpp
)

add_library(Xidi SHARED ${XIDI_MAIN_SOURCES} Resources/Xidi.rc Xidi.def)
set_target_properties(Xidi PROPERTIES OUTPUT_NAME "Xidi.${XIDI_ARCH}" PREFIX "")
xidi_common(Xidi)
target_include_directories(Xidi PRIVATE ${XIDI_SDL3_INCLUDE_DIRS})
target_link_libraries(Xidi PRIVATE ${XIDI_SDL3_TARGET} Xidi_Boost Xidi_XstdBitSet)
# SDL3_test is listed in the VS link line; link it only if present
if(TARGET SDL3::SDL3_test)
  target_link_libraries(Xidi PRIVATE SDL3::SDL3_test)
endif()
target_link_options(Xidi PRIVATE "/DEF:${CMAKE_SOURCE_DIR}/Xidi.def")
target_link_libraries(Xidi PRIVATE shlwapi setupapi winmm imm32 version)
# Copy SDL3.dll next to Xidi.<arch>.dll so it is found at runtime
if(NOT XIDI_SDL3_STATIC AND TARGET SDL3::SDL3-shared)
  add_custom_command(TARGET Xidi POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:SDL3::SDL3-shared> $<TARGET_FILE_DIR:Xidi>
    VERBATIM)
endif()

# ---- Forwarder DLLs (dinput.dll / dinput8.dll / winmm.dll) ---------------------
if(XIDI_BUILD_FORWARDERS)
  # Put MASM objects directly in $(IntDir) (ml.exe will not create a Source/ subfolder), as the VS projects do
  set_source_files_properties(
    Source/ForwardedApiDInput.asm Source/ForwardedApiDInput8.asm Source/ForwardedApiWinMM.asm
    PROPERTIES VS_SETTINGS "ObjectFileName=$(IntDir)%(Filename).obj")
  # MASM sources pick 32/64-bit code via _WIN32/_WIN64 (Infra Preamble.inc / Registers.inc).
  # Set per source file: the VS generator ignores per-language genex definitions for MASM.
  if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(XIDI_ASM_BITNESS_DEFINE _WIN64)
  else()
    set(XIDI_ASM_BITNESS_DEFINE _WIN32)
  endif()
  set_property(SOURCE
    Source/ForwardedApiDInput.asm Source/ForwardedApiDInput8.asm Source/ForwardedApiWinMM.asm
    APPEND PROPERTY COMPILE_DEFINITIONS ${XIDI_ASM_BITNESS_DEFINE} "$<$<CONFIG:Debug>:_DEBUG>")

  set(XIDI_DINPUT_SOURCES
      Source/DllFunctions.cpp
      Source/DllMain.cpp
      Source/ForwardedApiDInput.cpp
      Source/Globals.cpp
      Source/Strings.cpp
      Source/ForwardedApiDInput.asm
  )

  add_library(DInput SHARED ${XIDI_DINPUT_SOURCES} Resources/Xidi.rc Resources/DInput.rc dinput.def)
  set_target_properties(DInput PROPERTIES OUTPUT_NAME "dinput" PREFIX "")
  xidi_common(DInput)
  target_link_libraries(DInput PRIVATE Xidi_Boost Xidi_XstdBitSet)
  target_link_options(DInput PRIVATE "/DEF:${CMAKE_SOURCE_DIR}/dinput.def")
  target_compile_definitions(DInput PRIVATE XIDI_SKIP_CONFIG XIDI_SKIP_MAPPERS _WINDLL)

  set(XIDI_DINPUT8_SOURCES
      Source/DllFunctions.cpp
      Source/DllMain.cpp
      Source/ForwardedApiDInput8.cpp
      Source/Globals.cpp
      Source/Strings.cpp
      Source/ForwardedApiDInput8.asm
  )

  add_library(DInput8 SHARED ${XIDI_DINPUT8_SOURCES} Resources/Xidi.rc Resources/DInput8.rc dinput8.def)
  set_target_properties(DInput8 PROPERTIES OUTPUT_NAME "dinput8" PREFIX "")
  xidi_common(DInput8)
  target_link_libraries(DInput8 PRIVATE Xidi_Boost Xidi_XstdBitSet)
  target_link_options(DInput8 PRIVATE "/DEF:${CMAKE_SOURCE_DIR}/dinput8.def")
  target_compile_definitions(DInput8 PRIVATE XIDI_SKIP_CONFIG XIDI_SKIP_MAPPERS _WINDLL)

  set(XIDI_WINMM_SOURCES
      Source/DllFunctions.cpp
      Source/DllMain.cpp
      Source/ForwardedApiWinMM.cpp
      Source/Globals.cpp
      Source/Strings.cpp
      Source/ForwardedApiWinMM.asm
  )

  add_library(WinMM SHARED ${XIDI_WINMM_SOURCES} Resources/Xidi.rc Resources/WinMM.rc winmm.def)
  set_target_properties(WinMM PROPERTIES OUTPUT_NAME "winmm" PREFIX "")
  xidi_common(WinMM)
  target_link_libraries(WinMM PRIVATE Xidi_Boost Xidi_XstdBitSet)
  target_link_options(WinMM PRIVATE "/DEF:${CMAKE_SOURCE_DIR}/winmm.def")
  target_compile_definitions(WinMM PRIVATE XIDI_SKIP_CONFIG XIDI_SKIP_MAPPERS _WINDLL)
endif()

# ---- Hookshot hook module -------------------------------------------------------
if(XIDI_BUILD_HOOK_MODULE)
  set(XIDI_HOOKMODULE_SOURCES
      Source/ApiDirectInput.cpp
      Source/ApiGUID.cpp
      Source/ApiXidi.cpp
      Source/ApiXidiMetadata.cpp
      Source/DllMain.cpp
      Source/Globals.cpp
      Source/HookModuleMain.cpp
      Source/Hooks/CoCreateInstance.cpp
      Source/SetHooks.cpp
      Source/Strings.cpp
      Source/XidiConfigReader.cpp
  )
  add_library(HookModule SHARED ${XIDI_HOOKMODULE_SOURCES} Resources/Xidi.rc Resources/HookModule.rc)
  set_target_properties(HookModule PROPERTIES OUTPUT_NAME "Xidi.HookModule.${XIDI_ARCH}" PREFIX "")
  xidi_common(HookModule)
  target_include_directories(HookModule PRIVATE ${XIDI_SDL3_INCLUDE_DIRS})
  target_link_libraries(HookModule PRIVATE Xidi_Hookshot shlwapi)
  target_compile_definitions(HookModule PRIVATE XIDI_SKIP_MAPPERS _WINDLL)
endif()

# ---- Tests -----------------------------------------------------------------------
if(XIDI_BUILD_TESTS)
  enable_testing()
  set(XIDI_TEST_SOURCES
      Source/ApiDirectInput.cpp
      Source/ApiGUID.cpp
      Source/ApiXidi.cpp
      Source/ControllerIdentification.cpp
      Source/ControllerMath.cpp
      Source/DataFormat.cpp
      Source/DllFunctions.cpp
      Source/ElementMapper.cpp
      Source/ForceFeedbackDevice.cpp
      Source/ForceFeedbackEffect.cpp
      Source/ForceFeedbackParameters.cpp
      Source/Globals.cpp
      Source/ImportApiWinMM.cpp
      Source/ImportApiXInput.cpp
      Source/Mapper.cpp
      Source/MapperBuilder.cpp
      Source/MapperDefinitions.cpp
      Source/MapperParser.cpp
      Source/StateChangeEventBuffer.cpp
      Source/Strings.cpp
      Source/Test/Case/AxisMapperTest.cpp
      Source/Test/Case/ButtonMapperTest.cpp
      Source/Test/Case/CompoundMapperTest.cpp
      Source/Test/Case/ConstantForceEffectTest.cpp
      Source/Test/Case/ControllerMathTest.cpp
      Source/Test/Case/DataFormatTest.cpp
      Source/Test/Case/DigitalAxisMapperTest.cpp
      Source/Test/Case/ForceFeedbackDeviceTest.cpp
      Source/Test/Case/ForceFeedbackEffectTest.cpp
      Source/Test/Case/ForceFeedbackParametersTest.cpp
      Source/Test/Case/InvertMapperTest.cpp
      Source/Test/Case/KeyboardMapperTest.cpp
      Source/Test/Case/MapperBuilderTest.cpp
      Source/Test/Case/MapperParserTest.cpp
      Source/Test/Case/MapperTest.cpp
      Source/Test/Case/MouseAxisMapperTest.cpp
      Source/Test/Case/MouseButtonMapperTest.cpp
      Source/Test/Case/MouseSpeedModifierMapperTest.cpp
      Source/Test/Case/PeriodicEffectTest.cpp
      Source/Test/Case/PovMapperTest.cpp
      Source/Test/Case/RampForceEffectTest.cpp
      Source/Test/Case/SplitMapperTest.cpp
      Source/Test/Case/StateChangeEventBufferTest.cpp
      Source/Test/Case/VirtualControllerTest.cpp
      Source/Test/Case/VirtualDirectInputDeviceTest.cpp
      Source/Test/Case/VirtualDirectInputEffectTest.cpp
      Source/Test/Case/WrapperIDirectInputTest.cpp
      Source/Test/MockDirectInput.cpp
      Source/Test/MockDirectInputDevice.cpp
      Source/Test/MockKeyboard.cpp
      Source/Test/MockMouse.cpp
      Source/Test/MockPhysicalController.cpp
      Source/Test/TestMain.cpp
      Source/VirtualController.cpp
      Source/VirtualDirectInputDevice.cpp
      Source/VirtualDirectInputEffect.cpp
      Source/WrapperIDirectInput.cpp
  )
  add_executable(XidiTest ${XIDI_TEST_SOURCES})
  target_include_directories(XidiTest PRIVATE
      Include/Xidi Include/Xidi/Internal Include/Xidi/Test ${XIDI_GENERATED_DIR}
      ${XIDI_SDL3_INCLUDE_DIRS})
  target_compile_options(XidiTest PRIVATE
      $<$<COMPILE_LANGUAGE:CXX>:/FI${CMAKE_SOURCE_DIR}/Resources/Xidi.h> /permissive-)
  target_compile_definitions(XidiTest PRIVATE XIDI_SKIP_CONFIG)
  target_link_libraries(XidiTest PRIVATE Infra::Test Infra::Core Xidi_Boost Xidi_XstdBitSet winmm)
  add_dependencies(XidiTest xidi_git_version)
  add_test(NAME XidiTest COMMAND XidiTest)
endif()
