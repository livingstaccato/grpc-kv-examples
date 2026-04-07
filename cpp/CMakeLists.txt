cmake_minimum_required(VERSION 3.16)
project(grpc-kv-cpp CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(Threads REQUIRED)
find_package(Protobuf REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(GRPC REQUIRED grpc++ grpc)
find_package(OpenSSL REQUIRED)

# Find tools
find_program(GRPC_CPP_PLUGIN grpc_cpp_plugin)
find_program(Protobuf_PROTOC_EXECUTABLE protoc)

message(STATUS "Using protoc: ${Protobuf_PROTOC_EXECUTABLE}")
message(STATUS "Using grpc_cpp_plugin: ${GRPC_CPP_PLUGIN}")

# Proto file
set(PROTO_FILE "${CMAKE_CURRENT_SOURCE_DIR}/../proto/kv.proto")
set(PROTO_SRC_DIR "${CMAKE_CURRENT_BINARY_DIR}")

# Generate protobuf and gRPC sources
set(PROTO_SRCS "${PROTO_SRC_DIR}/kv.pb.cc")
set(PROTO_HDRS "${PROTO_SRC_DIR}/kv.pb.h")
set(GRPC_SRCS "${PROTO_SRC_DIR}/kv.grpc.pb.cc")
set(GRPC_HDRS "${PROTO_SRC_DIR}/kv.grpc.pb.h")

add_custom_command(
    OUTPUT "${PROTO_SRCS}" "${PROTO_HDRS}" "${GRPC_SRCS}" "${GRPC_HDRS}"
    COMMAND ${Protobuf_PROTOC_EXECUTABLE}
    ARGS --grpc_out "${PROTO_SRC_DIR}"
         --cpp_out "${PROTO_SRC_DIR}"
         -I "${CMAKE_CURRENT_SOURCE_DIR}/../proto"
         --plugin=protoc-gen-grpc="${GRPC_CPP_PLUGIN}"
         "${PROTO_FILE}"
    DEPENDS "${PROTO_FILE}"
)

# Proto library
add_library(kv_proto ${PROTO_SRCS} ${GRPC_SRCS} ${PROTO_HDRS} ${GRPC_HDRS})
target_include_directories(kv_proto PUBLIC ${PROTO_SRC_DIR})
target_link_libraries(kv_proto
    PUBLIC
    ${Protobuf_LIBRARIES}
    ${GRPC_LIBRARIES}
)

# Server executable
add_executable(kv-server src/server.cpp)
target_include_directories(kv-server PRIVATE ${PROTO_SRC_DIR} ${GRPC_INCLUDE_DIRS})
target_link_libraries(kv-server
    kv_proto
    ${GRPC_LIBRARIES}
    OpenSSL::SSL
    OpenSSL::Crypto
    Threads::Threads
)

# Client executable
add_executable(kv-client src/client.cpp)
target_include_directories(kv-client PRIVATE ${PROTO_SRC_DIR} ${GRPC_INCLUDE_DIRS})
target_link_libraries(kv-client
    kv_proto
    ${GRPC_LIBRARIES}
    OpenSSL::SSL
    OpenSSL::Crypto
    Threads::Threads
)
