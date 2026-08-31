#include "core/app.hpp"
#include "core/log/logger.hpp"

#include <iostream>
#include <string>

int main(int argc, char *argv[]) {
  xyla::App app;
  xyla::Logger::instance().init();
  xyla::ErrorCode err = app.init(argc, argv);

  if (err != xyla::ErrorCode::None) {
    std::string errStr = "Xyla Engine Fatal Boot Failure [Error Code: " +
                         std::to_string(static_cast<int>(err)) + "]";

    XYLA_LOG_ERROR("Boot", errStr);

    std::cerr << errStr << std::endl;
    return static_cast<int>(err);
  }

  return app.run();
}
