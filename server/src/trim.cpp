#include "trim.hpp"

const char *whitespace {" \t\n\r"};

std::string& trim_left(std::string &s) {
  s.erase(0, s.find_first_not_of(whitespace));
  return s;
}

std::string& trim_right(std::string &s) {
  s.erase(s.find_last_not_of(whitespace) + 1);
  return s;
}

std::string& trim(std::string &s) {
  return trim_left(trim_right(s));
}
