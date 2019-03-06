#!/bin/bash
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

. ${CTS_TOP_DIR}/lib/common.sh
assert_eq $# 2 "Usage: Require two arguments, two collections in different scopes. First collection is dropped"

echo "Running drop collection test - the test will drop $1 from ${CTS_CB_BUCKET}"

COLLECTION1=$1
COLLECTION2=$2
assert_ne $1 $2 "$1 and $2 match"

COLLECTION1_ID=`${CTS_PYTHON3} ${CTS_BIN}/get_cid.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 ${COLLECTION1}`
assert_eq $? 0 "Cannot map to ID collection ${COLLECTION1}"

COLLECTION2_SCOPE_ID=`${CTS_PYTHON3} ${CTS_BIN}/get_scope_id.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 ${COLLECTION2}`
assert_eq $? 0 "Cannot map to ID scope ${COLLECTION2}"

# Make JSON filter documents
mktemp_tracked SCOPE_JSON
mktemp_tracked COLLECTION_JSON
mktemp_tracked STREAM_ID_JSON
echo -e "{\"scope\":\"${COLLECTION2_SCOPE_ID}\"}" > ${SCOPE_JSON}
echo -e "{\"collections\":[\"${COLLECTION1_ID}\"]}" > ${COLLECTION_JSON}
# stream ID!
echo -ne "{\"streams\":[" > ${STREAM_ID_JSON}
echo -ne "{\"sid\":99, \"scope\":\"${COLLECTION2_SCOPE_ID}\"}," >> ${STREAM_ID_JSON}
echo -ne "{\"sid\":199, \"collections\":[\"${COLLECTION1_ID}\"]}]}" >> ${STREAM_ID_JSON}

# Establish our background pydcp clients
mktemp_tracked LEGACY_DCP
${CTS_PYTHON} -u ${CTS_PYDCP}/simple_dcp_client.py --node ${CTS_CB_NODE}:${CTS_CB_DATA_PORT} --bucket ${CTS_CB_BUCKET} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --keys -t -1 2>&1 > ${LEGACY_DCP} &
register_pid LEGACY_DCP_PID

mktemp_tracked ALL_DCP
${CTS_PYTHON} -u ${CTS_PYDCP}/simple_dcp_client.py --node ${CTS_CB_NODE}:${CTS_CB_DATA_PORT} --bucket ${CTS_CB_BUCKET} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --collections --keys -t -1 2>&1 > ${ALL_DCP} &
register_pid ALL_DCP_PID

mktemp_tracked COLLECTION_DCP
${CTS_PYTHON} -u ${CTS_PYDCP}/simple_dcp_client.py --node ${CTS_CB_NODE}:${CTS_CB_DATA_PORT} --bucket ${CTS_CB_BUCKET} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD}  --keys  --collections -t -1 -f ${COLLECTION_JSON} 2>&1 > ${COLLECTION_DCP} &
register_pid COLLECTION_DCP_PID

mktemp_tracked SCOPE_DCP
${CTS_PYTHON} -u ${CTS_PYDCP}/simple_dcp_client.py --node ${CTS_CB_NODE}:${CTS_CB_DATA_PORT} --bucket ${CTS_CB_BUCKET} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --collections --keys -t -1 -f ${SCOPE_JSON} 2>&1 > ${SCOPE_DCP} &
register_pid SCOPE_DCP_PID

mktemp_tracked STREAM_ID_DCP
${CTS_PYTHON} -u ${CTS_PYDCP}/simple_dcp_client.py --node ${CTS_CB_NODE}:${CTS_CB_DATA_PORT} --bucket ${CTS_CB_BUCKET} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --collections --enable-stream-id --keys -t -1 -f ${STREAM_ID_JSON} 2>&1 > ${STREAM_ID_DCP} &
register_pid STREAM_ID_DCP_PID

cecho "Legacy stream DCP output ${LEGACY_DCP}" $green
cecho "All stream DCP output ${ALL_DCP}" $green
cecho "Collection stream DCP output ${COLLECTION_DCP}" $green
cecho "Scope stream DCP output ${SCOPE_DCP}" $green
cecho "Stream-ID DCP output ${STREAM_ID_DCP}" $green

${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${CTS_CB_BUCKET} --drop-collection ${COLLECTION1}
assert_eq $? 0 "Failed drop of collection ${COLLECTION1}"

cecho "Success Dropped ${COLLECTION1}" $green

wait ${COLLECTION_DCP_PID}

# Now check other processes stayed-alive and generate a special key into the output
KEY=`date "+%F-%T"`
KEY="terminator_${KEY}"

# Write a special key to the streamed vbucket and check it comes through
# write to default collection
${CTS_PYTHON3} ${CTS_BIN}/write_key.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 ${KEY} _default._default
expect_eq $? 0 "Expected success writing to _default._default"

# write to the dropped collection (by-id) (expect error)
${CTS_PYTHON3} ${CTS_BIN}/write_key.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 ${KEY} ${COLLECTION1_ID}
expect_eq $? 1 "Expected error writing to collection:${COLLECTION1_ID}"

# write to other collection in other scope
${CTS_PYTHON3} ${CTS_BIN}/write_key.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 ${KEY} ${COLLECTION2}
expect_eq $? 0 "Expected success writing to ${COLLECTION2}"

# Wait for the terminator key to appear on all streams and then kill
while ! grep -q ${KEY} ${LEGACY_DCP};
do
    echo -n "*"
    sleep 1
done
echo
while ! grep -q ${KEY} ${ALL_DCP};
do
    echo -n "."
    sleep 1
done
echo
while ! grep -q ${KEY} ${SCOPE_DCP};
do
    echo -n "#"
    sleep 1
done
echo

# Legacy sees no events, only the stream end
assert_not_grep "DCP Event" ${LEGACY_DCP}

assert_grep "CollectionDROPPED, id:$COLLECTION1_ID" ${COLLECTION_DCP}
assert_grep "Stream complete with reason 7" ${COLLECTION_DCP}

assert_grep "CollectionDROPPED, id:$COLLECTION1_ID" ${ALL_DCP}
# Expect to see stream end in streamID stream
assert_grep "Received stream end. Stream complete with reason 7" ${STREAM_ID_DCP}
# Expect to see the collection was dropped in stream-ID
assert_grep "CollectionDROPPED, id:$COLLECTION1_ID" ${STREAM_ID_DCP}

# Scope stream is looking elsewhere
assert_not_grep "CollectionDROPPED, id:$COLLECTION1_ID" ${SCOPE_DCP}

# Legacy sees nothing
assert_not_grep "CollectionDROPPED, id:$COLLECTION1_ID" ${LEGACY_DCP}

cecho "Success?" $green
exit 0