project(messagedb-server)

add_library(messagedb-lib STATIC trim.cpp trim.hpp)
target_include_directories(messagedb-lib PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

add_executable(messagedb-server server.cpp db.cpp)

if(BUILD_STATIC)
  set(CMAKE_EXE_LINKER_FLAGS "-static")
  target_link_libraries(messagedb-server LINK_PRIVATE messagedb-lib boost_system pqxx pq ssl crypto dl)
else()
  target_link_libraries(messagedb-server LINK_PRIVATE messagedb-lib boost_system pqxx)
endif()

