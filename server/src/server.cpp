#include "db.hpp"

#include <boost/asio.hpp>

#include <cstdlib>
#include <iostream>
#include <memory>
#include <optional>
#include <string>

using boost::asio::ip::tcp;

class tcp_connection
  : public std::enable_shared_from_this<tcp_connection>
{
public:
  tcp::socket& socket() { return socket_; }

  void start()
  {
    socket_.async_read_some(boost::asio::buffer(read_buffer, read_buffer.size()),
      [o{shared_from_this()}] (const boost::system::error_code& error, size_t bytes_transferred) {
        o->handle_read(error, bytes_transferred);
      });
  }

  tcp_connection(boost::asio::io_service& io_service, MessageDb &db)
    : socket_(io_service), db_{db}
  { }

private:
  void handle_read(const boost::system::error_code& /*error*/, size_t bytes_transferred)
  {
    const std::string message{read_buffer.data(), bytes_transferred};
    std::cout << "got message " << message << '\n';
    db_.post_message(message);

    boost::asio::async_write(socket_, boost::asio::buffer("ok"),
      [o{shared_from_this()}] (const boost::system::error_code& error, size_t bytes_transferred) {
        o->handle_write(error, bytes_transferred);
      });
  }

  void handle_write(const boost::system::error_code& /*error*/,
      size_t /*bytes_transferred*/)
  { }

  tcp::socket socket_;
  std::array<char, 500> read_buffer;
  MessageDb &db_;
};

class tcp_server
{
public:
  tcp_server(boost::asio::io_service& io_service, MessageDb mdb)
    : acceptor_(io_service, tcp::endpoint(tcp::v4(), 1300)),
      db_{std::move(mdb)}
  {
    start_accept();
  }

private:
  void start_accept()
  {
    auto new_connection{std::make_shared<tcp_connection>(acceptor_.get_io_service(), db_)};

    acceptor_.async_accept(new_connection->socket(),
      [this, new_connection] (const boost::system::error_code& error) {
        if (!error) {
          new_connection->start();
          start_accept();
        }
      });
  }

  tcp::acceptor acceptor_;
  MessageDb     db_;
};

static std::optional<std::string> get_env(const std::string &env_var) {
  const char *env_pointer{std::getenv(env_var.c_str())};
  if (env_pointer) {
    return {env_pointer};
  }
  return {};
}

int main()
{
  const auto db_name{get_env("MDB_DB")};
  const auto db_user{get_env("MDB_USER")};
  const auto db_pass{get_env("MDB_PASS")};
  const auto db_host{get_env("MDB_HOST")};

  if (!db_name || !db_user || !db_pass || !db_host) {
    std::cerr << "Need the following environment variables:\n"
                 " - MDB_DB\n"
                 " - MDB_USER\n"
                 " - MDB_PASS\n"
                 " - MDB_HOST\n";
    return 1;
  }

  try {
    boost::asio::io_service io_service;
    tcp_server server{io_service, {*db_name, *db_user, *db_pass, *db_host}};
    io_service.run();
  } catch (const std::exception& e) {
    std::cerr << e.what() << std::endl;
  }

  return 0;
}
