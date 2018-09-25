project(messagedb-server)

add_executable(messagedb-server server.cpp db.cpp)

if(BUILD_STATIC)
  set(CMAKE_EXE_LINKER_FLAGS "-static")
  target_link_libraries(messagedb-server LINK_PRIVATE boost_system pqxx pq ssl crypto pthread dl)
else()
  target_link_libraries(messagedb-server LINK_PRIVATE boost_system pqxx)
endif()

