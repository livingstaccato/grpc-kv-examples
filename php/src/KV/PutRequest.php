<?php
// Generated PHP class for PutRequest
namespace KV;

use Google\Protobuf\Internal\Message;

class PutRequest extends Message
{
    protected $key = '';
    protected $value = '';

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
            if (isset($data['value'])) {
                $this->value = $data['value'];
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

    public function getValue(): string
    {
        return $this->value;
    }

    public function setValue(string $value): self
    {
        $this->value = $value;
        return $this;
    }

    public function serializeToString(): string
    {
        $result = '';
        if ($this->key !== '') {
            $result .= "\x0a" . chr(strlen($this->key)) . $this->key;
        }
        if ($this->value !== '') {
            $result .= "\x12" . chr(strlen($this->value)) . $this->value;
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

            if ($wireType === 2) {
                $strLen = ord($data[$pos++]);
                $str = substr($data, $pos, $strLen);
                $pos += $strLen;

                if ($fieldNum === 1) {
                    $this->key = $str;
                } elseif ($fieldNum === 2) {
                    $this->value = $str;
                }
            }
        }
    }
}
