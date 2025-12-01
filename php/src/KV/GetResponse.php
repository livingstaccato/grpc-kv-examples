<?php
// Generated PHP class for GetResponse
namespace KV;

use Google\Protobuf\Internal\Message;

class GetResponse extends Message
{
    protected $value = '';

    public function __construct($data = null)
    {
        $this->initializeFromArray($data);
    }

    private function initializeFromArray($data)
    {
        if (is_array($data)) {
            if (isset($data['value'])) {
                $this->value = $data['value'];
            }
        }
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
        if ($this->value !== '') {
            $result .= "\x0a" . chr(strlen($this->value)) . $this->value;
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
                $this->value = substr($data, $pos, $strLen);
                $pos += $strLen;
            }
        }
    }
}
