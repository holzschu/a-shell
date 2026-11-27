cmake_minimum_required(VERSION 3.24)
project(AShellDuckDB LANGUAGES C CXX)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS" OR NOT EXISTS "${IOS_SYSTEM_FRAMEWORK}/ios_system")
    message(FATAL_ERROR "Select an iOS SDK and the matching -DIOS_SYSTEM_FRAMEWORK=/path/to/ios_system.framework")
endif()

set(BUILD_SHELL OFF CACHE BOOL "" FORCE)
set(BUILD_UNITTESTS OFF CACHE BOOL "" FORCE)
set(DISABLE_EXTENSION_LOAD ON CACHE BOOL "" FORCE)
set(DISABLE_BUILTIN_HTTPLIB ON CACHE BOOL "" FORCE)
set(ENABLE_JEMALLOC OFF CACHE BOOL "" FORCE)
set(SMALLER_BINARY ON CACHE BOOL "" FORCE)
# Cross-compilation must not execute DuckDB's host platform detector.
set(DUCKDB_EXPLICIT_PLATFORM ios CACHE STRING "" FORCE)
set(OVERRIDE_GIT_DESCRIBE v1.5.4-0-g08e34c447b CACHE STRING "" FORCE)
set(DUCKDB_EXTENSION_CONFIGS "${CMAKE_CURRENT_SOURCE_DIR}/extensions.cmake" CACHE STRING "" FORCE)

include(FetchContent)
FetchContent_Declare(duckdb
    URL https://codeload.github.com/duckdb/duckdb/tar.gz/08e34c447bae34eaee3723cac61f2878b6bdf787
    URL_HASH SHA256=0deb78bb53dd5030323503b2f3ff5d52d66af7969dcf1f3849a203d7c769e481
    DOWNLOAD_EXTRACT_TIMESTAMP FALSE
)
FetchContent_MakeAvailable(duckdb)

add_library(DuckDBCommand SHARED command.cpp)
target_compile_features(DuckDBCommand PRIVATE cxx_std_11)
target_compile_definitions(DuckDBCommand PRIVATE ASHELL_DUCKDB)
target_include_directories(DuckDBCommand PRIVATE "${duckdb_SOURCE_DIR}/src/include")
target_link_libraries(DuckDBCommand PRIVATE
    duckdb_static duckdb_generated_extension_loader core_functions_extension parquet_extension json_extension
    "${IOS_SYSTEM_FRAMEWORK}"
)
target_link_options(DuckDBCommand PRIVATE "LINKER:-dead_strip" "LINKER:-exported_symbol,_duckdb_ios_main")
set_target_properties(DuckDBCommand PROPERTIES
    FRAMEWORK TRUE
    MACOSX_FRAMEWORK_IDENTIFIER org.duckdb.a-Shell.command
    INSTALL_NAME_DIR "@rpath"
    BUILD_WITH_INSTALL_NAME_DIR YES
    SKIP_BUILD_RPATH YES
)
