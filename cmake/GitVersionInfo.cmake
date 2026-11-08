# Generates GitVersionInfo.generated.h on every build (CMake equivalent of GitVersionInfo.bat).
set(XIDI_GENERATED_DIR "${CMAKE_BINARY_DIR}/generated" CACHE INTERNAL "")
file(MAKE_DIRECTORY "${XIDI_GENERATED_DIR}")

add_custom_target(xidi_git_version
  COMMAND ${CMAKE_COMMAND}
          -DSOURCE_DIR=${CMAKE_SOURCE_DIR}
          -DOUTPUT_FILE=${XIDI_GENERATED_DIR}/GitVersionInfo.generated.h
          -DEXTRA_ARG=$<$<CONFIG:Debug>:debug>
          -P ${CMAKE_CURRENT_LIST_DIR}/GitVersionInfoGenerate.cmake
  BYPRODUCTS ${XIDI_GENERATED_DIR}/GitVersionInfo.generated.h
  COMMENT "Generating Git version information"
  VERBATIM)
