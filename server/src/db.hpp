#include <pqxx/pqxx>

#include <memory>
#include <optional>

class MessageDb {
public:
  MessageDb(std::string db_name, std::string user, std::string password, std::string hostname);
  bool post_message(std::string message);

private:
  std::shared_ptr<pqxx::connection> connection_;
};
