#include "db.hpp"

#include <cassert>
#include <iostream>
#include <sstream>

std::shared_ptr<pqxx::connection> connect_to_db(
    std::string db_name, std::string user, std::string password,
    std::string hostname) {
  struct DbDeleter {
    void operator()(pqxx::connection* p) const {
      p->close();
      delete p;
    }
  };

  std::ostringstream ss;
  ss << "dbname = " << db_name << " user = " << user << " password = "
     << password << " hostaddr = " << hostname << " port = 5432";

  try {
    std::shared_ptr<pqxx::connection> c {new pqxx::connection{ss.str()}, DbDeleter{}};
    if (c->is_open()) {
      return c;
    }
  } catch (const std::exception &e) {
    std::cerr << "Unable to connect to DB: " << e.what() << '\n';
  }

  return {};
}

static bool create_table(pqxx::connection &c) {
  const auto sql = "CREATE TABLE testcounter ("
     "id             SERIAL  PRIMARY KEY NOT NULL,"
     "content        TEXT    NOT NULL,"
     "date           DATE    NOT NULL DEFAULT CURRENT_DATE);";

  try {
    pqxx::work w(c);
    w.exec( sql );
    w.commit();
    return true;
  } catch (const std::exception &e) {
    return false;
  }
}

static bool insert_text_entry(pqxx::connection &c, std::string text) {
  std::ostringstream ss;
  ss << "INSERT INTO testcounter (content) VALUES ('" << text << "');";

  try {
    pqxx::work w(c);
    w.exec(ss.str());
    w.commit();
  } catch (const std::exception& e) {
    std::cerr << "Unable to insert text: " << e.what() << '\n';
    return false;
  }
  return true;
}

MessageDb::MessageDb(std::string db_name, std::string user, std::string password, std::string hostname)
  : connection_{connect_to_db(db_name, user, password, hostname)}
{
  assert(connection_);
  create_table(*connection_);
}

bool MessageDb::post_message(std::string message) {
  return insert_text_entry(*connection_, message);
}
