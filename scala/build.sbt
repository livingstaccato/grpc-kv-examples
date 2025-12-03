name := "grpc-kv-scala"
version := "1.0.0"
scalaVersion := "3.3.1"

// Enable ScalaPB
Compile / PB.targets := Seq(
  scalapb.gen(grpc = true) -> (Compile / sourceManaged).value / "scalapb"
)

// gRPC and Protocol Buffers dependencies
libraryDependencies ++= Seq(
  "io.grpc" % "grpc-netty" % "1.77.0",
  "com.thesamet.scalapb" %% "scalapb-runtime-grpc" % scalapb.compiler.Version.scalapbVersion,
  "com.thesamet.scalapb" %% "scalapb-runtime" % scalapb.compiler.Version.scalapbVersion % "protobuf"
)

// Protocol Buffers settings
Compile / PB.protoSources := Seq(file("../proto"))
