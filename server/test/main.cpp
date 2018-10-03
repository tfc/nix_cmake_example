#include "trim.hpp"

#include <gtest/gtest.h>

#include <string>

using namespace std::string_literals;

TEST(Trimp, TrimLeftWorks) {
  auto s {"   hello"s};
  EXPECT_EQ("hello"s, trim_left(s));
}

TEST(Trimp, TrimRightWorks) {
  auto s {"hello   "s};
  EXPECT_EQ("hello"s, trim_right(s));
}

TEST(Trimp, TrimWorks) {
  auto s {"   hello   "s};
  EXPECT_EQ("hello"s, trim(s));
}

int main(int argc, char **argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
