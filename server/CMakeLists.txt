cmake_minimum_required(VERSION 3.6)

set (CMAKE_CXX_STANDARD 17)

# The project name
project(example_server)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

set(CMAKE_CXX_FLAGS_DEBUG "-g -pthread")
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -pthread")

add_compile_options(-Wall -Wextra -pedantic -Werror)

add_subdirectory(src)

option(ENABLE_TESTS "Enable tests" OFF)
if (${ENABLE_TESTS})
  enable_testing()
  add_subdirectory(test)
endif()

