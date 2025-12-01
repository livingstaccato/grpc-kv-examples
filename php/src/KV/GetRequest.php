<?php
// Generated PHP class for GetRequest
namespace KV;

use Google\Protobuf\Internal\Message;
use Google\Protobuf\Internal\GPBType;

class GetRequest extends Message
{
    protected $key = '';

    public function __construct($data = null)
    {
        $this->initializeFromArray($data);
    }

    private function initializeFromArray($data)
    {
        if (is_array($data)) {
            if (isset($data['key'])) {
                $this->key = $data['key'];
            }
        }
    }

    public function getKey(): string
    {
        return $this->key;
    }

    public function setKey(string $value): self
    {
        $this->key = $value;
        return $this;
    }

    public function serializeToString(): string
    {
        $result = '';
        if ($this->key !== '') {
            $result .= "\x0a" . chr(strlen($this->key)) . $this->key;
        }
        return $result;
    }

    public function mergeFromString(string $data): void
    {
        $pos = 0;
        $len = strlen($data);
        while ($pos < $len) {
            $tag = ord($data[$pos++]);
            $fieldNum = $tag >> 3;
            $wireType = $tag & 0x07;

            if ($fieldNum === 1 && $wireType === 2) {
                $strLen = ord($data[$pos++]);
                $this->key = substr($data, $pos, $strLen);
                $pos += $strLen;
            }
        }
    }
}
