# Infra: shared infrastructure (git submodule in the original repo)
set(INFRA_CORE_SOURCES
    Source/Core/Configuration.cpp
    Source/Core/Message.cpp
    Source/Core/ProcessInfo.cpp
    Source/Core/Resolver.cpp
    Source/Core/Strings.cpp
    Source/Core/SystemInfo.cpp
    Source/Core/TemporaryBuffer.cpp
    Source/Core/WindowsUtilities.cpp)

add_library(InfraCore STATIC ${INFRA_CORE_SOURCES})
add_library(Infra::Core ALIAS InfraCore)
target_include_directories(InfraCore
  PUBLIC  ${CMAKE_CURRENT_SOURCE_DIR}/Include            # <Infra/Core/...>
          ${XIDI_GENERATED_DIR}                            # ProcessInfo.h includes GitVersionInfo.generated.h
  PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/Include/Infra
          ${CMAKE_CURRENT_SOURCE_DIR}/Include/Infra/Internal)
add_dependencies(InfraCore xidi_git_version)
target_compile_definitions(InfraCore PRIVATE _CONSOLE)
set_target_properties(InfraCore PROPERTIES OUTPUT_NAME "CoreInfra")
if(MSVC)
  target_compile_options(InfraCore PRIVATE /permissive-)
endif()

if(XIDI_BUILD_TESTS)
  add_library(InfraTest STATIC
      Source/Test/Harness.cpp
      Source/Test/TestCase.cpp
      Source/Test/Utilities.cpp)
  add_library(Infra::Test ALIAS InfraTest)
  target_include_directories(InfraTest
    PUBLIC  ${CMAKE_CURRENT_SOURCE_DIR}/Include
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/Include/Infra
            ${CMAKE_CURRENT_SOURCE_DIR}/Include/Infra/Internal)
  target_link_libraries(InfraTest PUBLIC Infra::Core)
  if(MSVC)
    target_compile_options(InfraTest PRIVATE /permissive-)
  endif()

  add_executable(CoreInfraTest
      Source/Test/Case/ConfigurationTest.cpp
      Source/Test/Case/ResolverTest.cpp
      Source/Test/Case/StringsTest.cpp
      Source/Test/Case/TemporaryBufferTest.cpp
      Source/Test/TestMain.cpp)
  target_include_directories(CoreInfraTest PRIVATE
      ${CMAKE_CURRENT_SOURCE_DIR}/Include/Infra
      ${CMAKE_CURRENT_SOURCE_DIR}/Include/Infra/Internal
      ${CMAKE_CURRENT_SOURCE_DIR}/Include/Infra/Test)
  target_link_libraries(CoreInfraTest PRIVATE Infra::Test Infra::Core)
  add_test(NAME CoreInfraTest COMMAND CoreInfraTest)
endif()
