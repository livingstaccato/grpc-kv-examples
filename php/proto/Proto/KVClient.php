<?php
// GENERATED CODE -- DO NOT EDIT!

// Original file comments:
// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0
//
namespace Proto;

/**
 */
class KVClient extends \Grpc\BaseStub {

    /**
     * @param string $hostname hostname
     * @param array $opts channel options
     * @param \Grpc\Channel $channel (optional) re-use channel object
     */
    public function __construct($hostname, $opts, $channel = null) {
        parent::__construct($hostname, $opts, $channel);
    }

    /**
     * @param \Proto\GetRequest $argument input argument
     * @param array $metadata metadata
     * @param array $options call options
     * @return \Grpc\UnaryCall<\Proto\GetResponse>
     */
    public function Get(\Proto\GetRequest $argument,
      $metadata = [], $options = []) {
        return $this->_simpleRequest('/proto.KV/Get',
        $argument,
        ['\Proto\GetResponse', 'decode'],
        $metadata, $options);
    }

    /**
     * @param \Proto\PutRequest $argument input argument
     * @param array $metadata metadata
     * @param array $options call options
     * @return \Grpc\UnaryCall<\Proto\PBEmpty>
     */
    public function Put(\Proto\PutRequest $argument,
      $metadata = [], $options = []) {
        return $this->_simpleRequest('/proto.KV/Put',
        $argument,
        ['\Proto\PBEmpty', 'decode'],
        $metadata, $options);
    }

}
