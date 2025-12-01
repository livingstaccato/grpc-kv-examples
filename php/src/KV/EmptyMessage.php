<?php
// Generated PHP class for Empty message
namespace KV;

use Google\Protobuf\Internal\Message;

class EmptyMessage extends Message
{
    public function __construct($data = null)
    {
        // Empty message has no fields
    }

    public function serializeToString(): string
    {
        return '';
    }

    public function mergeFromString(string $data): void
    {
        // Empty message, nothing to parse
    }
}
