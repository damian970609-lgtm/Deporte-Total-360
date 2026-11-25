cmake_minimum_required(VERSION 3.22.1)
project(shadowkeys_noop LANGUAGES C CXX)

add_library(ShadowKeys SHARED shadowkeys_noop.cpp)

target_compile_features(ShadowKeys PRIVATE cxx_std_17)
target_compile_options(ShadowKeys PRIVATE -Wall -Wextra -Werror)
target_link_libraries(ShadowKeys PRIVATE log)
