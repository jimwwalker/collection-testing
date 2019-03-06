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

#
# Test drops the default collection
# - monitors legacy DCP and expects it to close
# - monitors all DCP and expect to see _default dropped
# - monitors _default scope DCP and expects to see _default dropped yet DCP stay
#   open.
# - monitors _default DCP as a collection stream and expects to see DROP and close.
# - monitors boths default scope and default collection on a stream-ID stream and
#   expects to see the drop/end-stream but DCP remains open.

. ${CTS_TOP_DIR}/lib/common.sh

assert_eq $# 1 "Usage: Require one argument, a collection in the default scope"

COLLECTION1=$1

echo "Running drop _default collection test - the test will drop _default._default from ${CTS_CB_BUCKET}"

DEFAULT_COLLECTION_ID=`${CTS_PYTHON3} ${CTS_BIN}/get_cid.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 _default._default`
assert_eq $? 0 "Cannot map _default._default to ID"

DEFAULT_SCOPE_ID=`${CTS_PYTHON3} ${CTS_BIN}/get_scope_id.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 _default._default`
assert_eq $? 0 "Cannot map _default._default to scope ID"

expect_eq 0 ${DEFAULT_COLLECTION_ID} "Expected default collection to be 0"
expect_eq 0 ${DEFAULT_SCOPE_ID} "Expected default scope to be 0"

# Make JSON filter documents
mktemp_tracked SCOPE_JSON
mktemp_tracked COLLECTION_JSON
mktemp_tracked STREAM_ID_JSON
echo -e "{\"scope\":\"${DEFAULT_SCOPE_ID}\"}" > ${SCOPE_JSON}
echo -e "{\"collections\":[\"${DEFAULT_COLLECTION_ID}\"]}" > ${COLLECTION_JSON}
# stream ID!
echo -ne "{\"streams\":[" > ${STREAM_ID_JSON}
echo -ne "{\"sid\":99, \"scope\":\"${DEFAULT_SCOPE_ID}\"}," >> ${STREAM_ID_JSON}
echo -ne "{\"sid\":199, \"collections\":[\"${DEFAULT_COLLECTION_ID}\"]}]}" >> ${STREAM_ID_JSON}

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

${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${CTS_CB_BUCKET} --drop-collection _default._default
assert_eq $? 0 "Failed drop of collection _default._default"

cecho "Success Dropped _default._default" $green

wait ${LEGACY_DCP_PID}
cat $LEGACY_DCP
# Now check other processes stayed-alive and generate a special key into the output
KEY=`date "+%F-%T"`
KEY="terminator_${KEY}"

# Write a special key to the streamed vbucket and check it comes through
# write to default collection (get an error)
${CTS_PYTHON3} ${CTS_BIN}/write_key.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 ${KEY} ${DEFAULT_COLLECTION_ID}
expect_eq $? 1 "Expected error writing to _default._default"

# write to other collection in the _default scope
${CTS_PYTHON3} ${CTS_BIN}/write_key.py ${CTS_CB_NODE} ${CTS_CB_DATA_PORT} ${CTS_CB_USER} ${CTS_CB_PASSWD} ${CTS_CB_BUCKET} 0 ${KEY} ${COLLECTION1}
expect_eq $? 0 "Expected success writing to ${COLLECTION2}"

# Wait for the terminator key to appear on all streams and then kill
while ! grep -q ${KEY} ${STREAM_ID_DCP};
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

assert_grep "Received stream end. Stream complete with reason 0" ${LEGACY_DCP}
assert_grep "Received stream end. Stream complete with reason 7" ${STREAM_ID_DCP}
assert_grep "Received stream end. Stream complete with reason 7" ${COLLECTION_DCP}
assert_not_grep "Received stream end. Stream complete with reason 7" ${ALL_DCP}
assert_not_grep "Received stream end. Stream complete with reason 7" ${SCOPE_DCP}

assert_grep "CollectionDROPPED, id:${DEFAULT_COLLECTION_ID}" ${ALL_DCP}
assert_grep "CollectionDROPPED, id:${DEFAULT_COLLECTION_ID}" ${SCOPE_DCP}
assert_grep "CollectionDROPPED, id:${DEFAULT_COLLECTION_ID}" ${COLLECTION_DCP}
assert_grep "CollectionDROPPED, id:${DEFAULT_COLLECTION_ID}" ${STREAM_ID_DCP}
assert_not_grep "CollectionDROPPED, id:${DEFAULT_COLLECTION_ID}" ${LEGACY_DCP}
assert_not_grep "DCP Event" ${LEGACY_DCP}

# Finally expect to be denied legacy DCP
${CTS_PYTHON} -u ${CTS_PYDCP}/simple_dcp_client.py --node ${CTS_CB_NODE}:${CTS_CB_DATA_PORT} --bucket ${CTS_CB_BUCKET} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --keys -t -1 2>&1 >> ${LEGACY_DCP}
expect_ne $? 0 "Expected failure trying to reconnect legacy DCP"
# Unknown collection for us!
assert_grep "Unhandled Stream Create Response 136 None" ${LEGACY_DCP}

cecho "Success?" $green
exit 0