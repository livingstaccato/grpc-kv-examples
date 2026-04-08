cmake_minimum_required(VERSION 3.16)
project(grpc-kv-cpp CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find Threads and OpenSSL
find_package(Threads REQUIRED)
find_package(OpenSSL REQUIRED)

# If CMAKE_PREFIX_PATH is set (patched build), we want to use the config files there
if(CMAKE_PREFIX_PATH)
    message(STATUS "Using gRPC from PREFIX: ${CMAKE_PREFIX_PATH}")
    set(Protobuf_DIR "${CMAKE_PREFIX_PATH}/lib/cmake/protobuf")
    set(gRPC_DIR "${CMAKE_PREFIX_PATH}/lib/cmake/grpc")
endif()

# Find Protobuf first as gRPC depends on it
find_package(Protobuf REQUIRED)
# Find gRPC
find_package(gRPC REQUIRED)

# Find tools
find_program(GRPC_CPP_PLUGIN grpc_cpp_plugin)
if(NOT Protobuf_PROTOC_EXECUTABLE)
    find_program(Protobuf_PROTOC_EXECUTABLE protoc)
endif()

message(STATUS "Using protoc: ${Protobuf_PROTOC_EXECUTABLE}")
message(STATUS "Using grpc_cpp_plugin: ${GRPC_CPP_PLUGIN}")

# Proto file
set(PROTO_FILE "${CMAKE_CURRENT_SOURCE_DIR}/../proto/kv.proto")
set(PROTO_SRC_DIR "${CMAKE_CURRENT_BINARY_DIR}/proto")
file(MAKE_DIRECTORY ${PROTO_SRC_DIR})

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
    gRPC::grpc++
)

# Client executable
add_executable(kv-client src/client.cpp)
target_include_directories(kv-client PRIVATE ${PROTO_SRC_DIR})

target_link_libraries(kv-client
    kv_proto
    gRPC::grpc++
    OpenSSL::SSL
    OpenSSL::Crypto
    Threads::Threads
    ${CMAKE_DL_LIBS}
)
