
```
# stripping gRPC timestamps.

sed -E 's/^I[0-9]+ ([^ ]+ ){2}//g' | grep -vE '(timer_manager|memory_quota|adding handshake|promise_based|TCP:|grpc_auth_property_iterator_next|channel_stack.cc|compression_filter.cc|filter_stack_call.cc)'

```
