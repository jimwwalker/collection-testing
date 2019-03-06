#!/usr/bin/env python3
#
# Copyright 2019 Couchbase, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import mc_bin_client
import sys

if len(sys.argv) < 7:
    msg = ('Usage: {} <node> <port> <user> <password> <bucket> <vbid> <key> <optional: "scopename.collectionname" or collection-ID>'.format(
        sys.argv[0]))
    print(msg, file=sys.stderr)
    sys.exit(1)

HOST = sys.argv[1]
PORT = sys.argv[2]
client = mc_bin_client.MemcachedClient(host=HOST, port=PORT)
client.sasl_auth_plain(user=sys.argv[3], password=sys.argv[4])
client.bucket_select(sys.argv[5])

collection=None
client.enable_xerror()
if len(sys.argv) == 9:
    client.enable_collections()

client.hello("write_key")

if len(sys.argv) == 9:
    try:
        collection=int(sys.argv[8], 16)
    except ValueError:
        collection=sys.argv[8]

key = sys.argv[7]
client.vbucketId = int(sys.argv[6])
print(client.set(key=key, exp=0, flags=0, val="value", collection=collection))
