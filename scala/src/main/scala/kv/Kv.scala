// Generated Protocol Buffer code for KV service
package kv

import com.google.protobuf.ByteString
import scalapb.{GeneratedMessage, GeneratedMessageCompanion}

final case class GetRequest(
    key: String = ""
) extends GeneratedMessage {
  def toProtoString: String = s"GetRequest(key=$key)"
  def serializedSize: Int = {
    var size = 0
    if (key.nonEmpty) {
      size += 1 + key.getBytes("UTF-8").length + 1
    }
    size
  }
  def writeTo(output: com.google.protobuf.CodedOutputStream): Unit = {
    if (key.nonEmpty) {
      output.writeString(1, key)
    }
  }
  def companion: GeneratedMessageCompanion[GetRequest] = GetRequest
}

object GetRequest extends GeneratedMessageCompanion[GetRequest] {
  def parseFrom(input: com.google.protobuf.CodedInputStream): GetRequest = {
    var key = ""
    var done = false
    while (!done) {
      val tag = input.readTag()
      tag match {
        case 0 => done = true
        case 10 => key = input.readString()
        case _ => input.skipField(tag)
      }
    }
    GetRequest(key)
  }
  lazy val defaultInstance: GetRequest = GetRequest()
  def javaDescriptor: com.google.protobuf.Descriptors.Descriptor = null
  def scalaDescriptor: scalapb.descriptors.Descriptor = null
  def messageReads: scalapb.descriptors.Reads[GetRequest] = null
  def messageCompanionForFieldNumber(number: Int): GeneratedMessageCompanion[_] = null
  val nestedMessagesCompanions: Seq[GeneratedMessageCompanion[_ <: GeneratedMessage]] = Seq.empty
  def enumCompanionForFieldNumber(number: Int): scalapb.GeneratedEnumCompanion[_] = null
}

final case class GetResponse(
    value: ByteString = ByteString.EMPTY
) extends GeneratedMessage {
  def toProtoString: String = s"GetResponse(value=${value.toStringUtf8})"
  def serializedSize: Int = {
    var size = 0
    if (!value.isEmpty) {
      size += 1 + value.size + 1
    }
    size
  }
  def writeTo(output: com.google.protobuf.CodedOutputStream): Unit = {
    if (!value.isEmpty) {
      output.writeBytes(1, value)
    }
  }
  def companion: GeneratedMessageCompanion[GetResponse] = GetResponse
}

object GetResponse extends GeneratedMessageCompanion[GetResponse] {
  def parseFrom(input: com.google.protobuf.CodedInputStream): GetResponse = {
    var value = ByteString.EMPTY
    var done = false
    while (!done) {
      val tag = input.readTag()
      tag match {
        case 0 => done = true
        case 10 => value = input.readBytes()
        case _ => input.skipField(tag)
      }
    }
    GetResponse(value)
  }
  lazy val defaultInstance: GetResponse = GetResponse()
  def javaDescriptor: com.google.protobuf.Descriptors.Descriptor = null
  def scalaDescriptor: scalapb.descriptors.Descriptor = null
  def messageReads: scalapb.descriptors.Reads[GetResponse] = null
  def messageCompanionForFieldNumber(number: Int): GeneratedMessageCompanion[_] = null
  val nestedMessagesCompanions: Seq[GeneratedMessageCompanion[_ <: GeneratedMessage]] = Seq.empty
  def enumCompanionForFieldNumber(number: Int): scalapb.GeneratedEnumCompanion[_] = null
}

final case class PutRequest(
    key: String = "",
    value: ByteString = ByteString.EMPTY
) extends GeneratedMessage {
  def toProtoString: String = s"PutRequest(key=$key, value=${value.toStringUtf8})"
  def serializedSize: Int = {
    var size = 0
    if (key.nonEmpty) {
      size += 1 + key.getBytes("UTF-8").length + 1
    }
    if (!value.isEmpty) {
      size += 1 + value.size + 1
    }
    size
  }
  def writeTo(output: com.google.protobuf.CodedOutputStream): Unit = {
    if (key.nonEmpty) {
      output.writeString(1, key)
    }
    if (!value.isEmpty) {
      output.writeBytes(2, value)
    }
  }
  def companion: GeneratedMessageCompanion[PutRequest] = PutRequest
}

object PutRequest extends GeneratedMessageCompanion[PutRequest] {
  def parseFrom(input: com.google.protobuf.CodedInputStream): PutRequest = {
    var key = ""
    var value = ByteString.EMPTY
    var done = false
    while (!done) {
      val tag = input.readTag()
      tag match {
        case 0 => done = true
        case 10 => key = input.readString()
        case 18 => value = input.readBytes()
        case _ => input.skipField(tag)
      }
    }
    PutRequest(key, value)
  }
  lazy val defaultInstance: PutRequest = PutRequest()
  def javaDescriptor: com.google.protobuf.Descriptors.Descriptor = null
  def scalaDescriptor: scalapb.descriptors.Descriptor = null
  def messageReads: scalapb.descriptors.Reads[PutRequest] = null
  def messageCompanionForFieldNumber(number: Int): GeneratedMessageCompanion[_] = null
  val nestedMessagesCompanions: Seq[GeneratedMessageCompanion[_ <: GeneratedMessage]] = Seq.empty
  def enumCompanionForFieldNumber(number: Int): scalapb.GeneratedEnumCompanion[_] = null
}

final case class Empty() extends GeneratedMessage {
  def toProtoString: String = "Empty()"
  def serializedSize: Int = 0
  def writeTo(output: com.google.protobuf.CodedOutputStream): Unit = {}
  def companion: GeneratedMessageCompanion[Empty] = Empty
}

object Empty extends GeneratedMessageCompanion[Empty] {
  def parseFrom(input: com.google.protobuf.CodedInputStream): Empty = {
    var done = false
    while (!done) {
      val tag = input.readTag()
      tag match {
        case 0 => done = true
        case _ => input.skipField(tag)
      }
    }
    Empty()
  }
  lazy val defaultInstance: Empty = Empty()
  def javaDescriptor: com.google.protobuf.Descriptors.Descriptor = null
  def scalaDescriptor: scalapb.descriptors.Descriptor = null
  def messageReads: scalapb.descriptors.Reads[Empty] = null
  def messageCompanionForFieldNumber(number: Int): GeneratedMessageCompanion[_] = null
  val nestedMessagesCompanions: Seq[GeneratedMessageCompanion[_ <: GeneratedMessage]] = Seq.empty
  def enumCompanionForFieldNumber(number: Int): scalapb.GeneratedEnumCompanion[_] = null
}
