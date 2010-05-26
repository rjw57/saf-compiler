# Specify the name of our project and the minimum CMake requirements.
project("SAF" C CXX)
cmake_minimum_required(VERSION 2.6)

# Our default build type is RelWithDebInfo (see
# http://techbase.kde.org/Development/CMake/Build_Types and
# http://www.cmake.org/Wiki/CMake_Useful_Variables#Compilers_and_Tools)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif(NOT CMAKE_BUILD_TYPE)

# Tell people what sort of build we are doing.
message(STATUS "Build type is ${CMAKE_BUILD_TYPE}.")

# Make use of any extra CMake modules we ship with.
list(APPEND CMAKE_MODULE_PATH
	${CMAKE_SOURCE_DIR}/cmake/llvm
	${CMAKE_SOURCE_DIR}/cmake/vala
)

# Compile the SAF language
add_subdirectory(saf)

# vim:sw=4:ts=4:autoindent
