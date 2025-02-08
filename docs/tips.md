
# stripping gRPC timestamps.
sed -E 's/^I[0-9]+ ([^ ]+ ){2}//g'
