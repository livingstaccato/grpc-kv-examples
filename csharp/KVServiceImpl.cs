using Grpc.Core;
using Microsoft.Extensions.Logging;
using Proto;

namespace CSharpGrpcServer;

public class KVServiceImpl : KV.KVBase
{
    private readonly ILogger<KVServiceImpl> _logger;
    private readonly Dictionary<string, byte[]> _store = new();

    public KVServiceImpl(ILogger<KVServiceImpl> logger)
    {
        _logger = logger;
    }

    public override Task<GetResponse> Get(GetRequest request, ServerCallContext context)
    {
        var key = request.Key;
        _logger.LogInformation("🔍 📥 Get request - Key: {Key}", key);

        // Log request metadata
        _logger.LogDebug("🔎 Request metadata:");
        foreach (var header in context.RequestHeaders)
        {
            _logger.LogDebug("🔎   {Key}: {Value}", header.Key, header.Value);
        }

        // Log peer info
        var peer = context.Peer;
        _logger.LogDebug("🔎 Peer: {Peer}", peer);

        // Log auth context
        var authContext = context.AuthContext;
        if (authContext.PeerIdentityPropertyName != null)
        {
            _logger.LogDebug("🔎 Peer identity property: {PeerIdentity}", authContext.PeerIdentityPropertyName);
        }
        _logger.LogDebug("🔎 Auth context properties: {PropertyCount}", authContext.Properties.Count());

        // Get value from store or return default
        byte[] value;
        if (_store.TryGetValue(key, out var storedValue))
        {
            value = storedValue;
            _logger.LogInformation("📦 Found value for key '{Key}': {ValueLength} bytes", key, value.Length);
        }
        else
        {
            value = System.Text.Encoding.UTF8.GetBytes("OK");
            _logger.LogInformation("📦 Key '{Key}' not found, returning default: OK", key);
        }

        var response = new GetResponse
        {
            Value = Google.Protobuf.ByteString.CopyFrom(value)
        };

        _logger.LogInformation("✅ Get request completed successfully 🎉");
        return Task.FromResult(response);
    }

    public override Task<Empty> Put(PutRequest request, ServerCallContext context)
    {
        var key = request.Key;
        var value = request.Value.ToByteArray();

        _logger.LogInformation("📝 📥 Put request - Key: {Key}, Value length: {ValueLength} bytes", key, value.Length);
        _logger.LogDebug("📝 Value: {Value}", System.Text.Encoding.UTF8.GetString(value));

        // Store the value
        _store[key] = value;
        _logger.LogDebug("💾 Stored key '{Key}' with {ValueLength} bytes", key, value.Length);

        _logger.LogInformation("✅ Put request completed successfully 🎉");
        return Task.FromResult(new Empty());
    }
}
