<?php
// gRPC KV Client class
namespace KV;

use Grpc\ChannelCredentials;
use Grpc\BaseStub;

class KVClient extends BaseStub
{
    public function __construct($hostname, $opts, $channel = null)
    {
        parent::__construct($hostname, $opts, $channel);
    }

    public function Get(GetRequest $request, $metadata = [], $options = [])
    {
        return $this->_simpleRequest(
            '/proto.KV/Get',
            $request,
            [GetResponse::class, 'decode'],
            $metadata,
            $options
        );
    }

    public function Put(PutRequest $request, $metadata = [], $options = [])
    {
        return $this->_simpleRequest(
            '/proto.KV/Put',
            $request,
            [EmptyMessage::class, 'decode'],
            $metadata,
            $options
        );
    }
}
