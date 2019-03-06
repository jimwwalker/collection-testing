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
assert_eq $# 2 "Usage: Require two arguments, two collection paths with different scopes. The scope of the first path is dropped"

COLLECTION1=$1
IFS='.' read -ra COMPONENTS <<< "$COLLECTION1"
SCOPE1=${COMPONENTS[0]}
COLLECTION2=$2
assert_ne $1 $2 "$1 and $2 match"

echo "Running drop scope test - the test will drop ${SCOPE} from ${CTS_CB_BUCKET}"

COLLECTION1_ID=`${CTS_PYTHON3} ${CTS_BIN}/get_cid.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 ${COLLECTION1}`
assert_eq $? 0 "Cannot map to ID collection ${COLLECTION1}"

COLLECTION1_SCOPE_ID=`${CTS_PYTHON3} ${CTS_BIN}/get_scope_id.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 ${COLLECTION1}`
assert_eq $? 0 "Cannot map to ID scope ${COLLECTION2}"

COLLECTION2_ID=`${CTS_PYTHON3} ${CTS_BIN}/get_cid.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 ${COLLECTION2}`
assert_eq $? 0 "Cannot map to ID collection ${COLLECTION2}"

# Make JSON filter documents
mktemp_tracked SCOPE_JSON
mktemp_tracked COLLECTION_JSON
mktemp_tracked STREAM_ID_JSON
echo -e "{\"scope\":\"${COLLECTION1_SCOPE_ID}\"}" > ${SCOPE_JSON}
echo -e "{\"collections\":[\"${COLLECTION2_ID}\"]}" > ${COLLECTION_JSON}
# stream ID!
echo -ne "{\"streams\":[" > ${STREAM_ID_JSON}
echo -ne "{\"sid\":99, \"scope\":\"${COLLECTION1_SCOPE_ID}\"}," >> ${STREAM_ID_JSON}
echo -ne "{\"sid\":199, \"collections\":[\"${COLLECTION2_ID}\"]}]}" >> ${STREAM_ID_JSON}

# Establish our background pydcp clients
mktemp_tracked LEGACY_DCP
mktemp_tracked ALL_DCP
mktemp_tracked COLLECTION_DCP
mktemp_tracked STREAM_ID_DCP
mktemp_tracked SCOPE_DCP

${CTS_PYTHON} -u ${CTS_PYDCP}/simple_dcp_client.py --node ${CTS_CB_NODE}:${CTS_CB_DATA_PORT} --bucket ${CTS_CB_BUCKET} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --keys -t -1 2>&1 > ${LEGACY_DCP} &
register_pid LEGACY_DCP_PID

${CTS_PYTHON} -u ${CTS_PYDCP}/simple_dcp_client.py --node ${CTS_CB_NODE}:${CTS_CB_DATA_PORT} --bucket ${CTS_CB_BUCKET} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --collections --keys -t -1 2>&1 > ${ALL_DCP} &
register_pid ALL_DCP_PID

${CTS_PYTHON} -u ${CTS_PYDCP}/simple_dcp_client.py --node ${CTS_CB_NODE}:${CTS_CB_DATA_PORT} --bucket ${CTS_CB_BUCKET} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD}  --keys  --collections -t -1 -f ${COLLECTION_JSON} 2>&1 > ${COLLECTION_DCP} &
register_pid COLLECTION_DCP_PID

${CTS_PYTHON} -u ${CTS_PYDCP}/simple_dcp_client.py --node ${CTS_CB_NODE}:${CTS_CB_DATA_PORT} --bucket ${CTS_CB_BUCKET} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --collections --keys -t -1 -f ${SCOPE_JSON} 2>&1 > ${SCOPE_DCP} &
register_pid SCOPE_DCP_PID

${CTS_PYTHON} -u ${CTS_PYDCP}/simple_dcp_client.py --node ${CTS_CB_NODE}:${CTS_CB_DATA_PORT} --bucket ${CTS_CB_BUCKET} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --collections --enable-stream-id --keys -t -1 -f ${STREAM_ID_JSON} 2>&1 > ${STREAM_ID_DCP} &
register_pid STREAM_ID_DCP_PID

cecho "Legacy stream DCP output ${LEGACY_DCP}" $green
cecho "All stream DCP output ${ALL_DCP}" $green
cecho "Collection stream DCP output ${COLLECTION_DCP}" $green
cecho "Scope stream DCP output ${SCOPE_DCP}" $green
cecho "Stream-ID DCP output ${STREAM_ID_DCP}" $green

# Drop the scope
${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${CTS_CB_BUCKET} --drop-scope ${SCOPE1}
assert_eq $? 0 "Failed drop of scope:${SCOPE1}"
cecho "Success Dropped ${SCOPE1}" $green

# Drop scope stream should terminate once all data has been transmitted
wait ${SCOPE_DCP_PID}

if ! grep -q "Stream complete with reason 7" ${SCOPE_DCP}; then
    cecho "Didn't find end-reason in scope stream" $red
fi

# Now check other processes stayed-alive and generate a special key into the output
KEY=`date "+%F-%T"`
KEY="terminator_${KEY}${RAND}"

# Write a special key to the streamed vbucket and check it comes through
# write to default collection
${CTS_PYTHON3} ${CTS_BIN}/write_key.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 ${KEY} _default._default
expect_eq $? 0 "Expected success writing to _default._default"

# write to the collection in the dropped scope
${CTS_PYTHON3} ${CTS_BIN}/write_key.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 ${KEY} ${COLLECTION1_ID}
expect_eq $? 1 "Expected error writing to collection:${COLLECTION1_ID}"

# write to other collection in other scope
${CTS_PYTHON3} ${CTS_BIN}/write_key.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 ${KEY} ${COLLECTION2}
expect_eq $? 0 "Expected success writing to ${COLLECTION2}"

# Wait for the terminator key to appear on all expected streams
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
while ! grep -q ${KEY} ${COLLECTION_DCP};
do
    echo -n "#"
    sleep 1
done
echo

while ! grep -q ${KEY} ${STREAM_ID_DCP};
do
    echo -n "-"
    sleep 1
done
echo

# Legacy sees no events, only the stream end
assert_not_grep "DCP Event" ${LEGACY_DCP}

# Expect to see collection and scope dropped message in the all stream
assert_grep "CollectionDROPPED, id:${COLLECTION1_ID}" ${ALL_DCP}
assert_grep "ScopeDROPPED, id:${COLLECTION1_SCOPE_ID}" ${ALL_DCP}

# Expect to see collection and scope dropped message in the stream-id stream
assert_grep "CollectionDROPPED, id:${COLLECTION1_ID}" ${STREAM_ID_DCP}
assert_grep "ScopeDROPPED, id:${COLLECTION1_SCOPE_ID}" ${STREAM_ID_DCP}
# And a stream-end
assert_grep "Received stream end. Stream complete with reason 7" ${STREAM_ID_DCP}

# Scope stream sees all
assert_grep "CollectionDROPPED, id:${COLLECTION1_ID}" ${SCOPE_DCP}
assert_grep "ScopeDROPPED, id:${COLLECTION1_SCOPE_ID}" ${SCOPE_DCP}
assert_grep "Received stream end. Stream complete with reason 7" ${SCOPE_DCP}

# Collection stream is looking elsewhere, sees no drops
assert_not_grep "CollectionDROPPED, id:$COLLECTION1_ID" ${COLLECTION_DCP}

# Legacy sees nothing
assert_not_grep "CollectionDROPPED, id:$COLLECTION1_ID" ${LEGACY_DCP}

cecho "Success?" $green
exit 0
