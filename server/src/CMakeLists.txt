project(messagedb-server)

add_executable(messagedb-server server.cpp db.cpp)
target_link_libraries(messagedb-server boost_system pqxx)
