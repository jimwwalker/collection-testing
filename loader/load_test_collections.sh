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
assert_eq $# 1 "Usage: Requires bucket name"

TARGET_BUCKET=$1

for SCOPE in  "shop" "minimart" "expressmart" "supermarket" "megamart";
do
    if ! ${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${TARGET_BUCKET} --create-scope ${SCOPE}; then
        echo "Failed create of scope ${SCOPE}"
        exit 1
    fi
done

# default
for COLLECTION in "beer" "wine" "meat" "fruit" "vegetable" "dairy" "sweets" "electricals" "household";
do
    if ! ${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${TARGET_BUCKET} --create-collection _default.${COLLECTION}; then
        echo "Failed create of collection ${COLLECTION}"
        exit 1
    fi
done

# shop
for COLLECTION in "beer" "wine" "sweets";
do
    if ! ${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${TARGET_BUCKET} --create-collection shop.${COLLECTION}; then
        echo "Failed create of collection ${COLLECTION}"
        exit 1
    fi
done

# minimart
for COLLECTION in "beer" "wine" "dairy" "sweets";
do
    if ! ${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${TARGET_BUCKET} --create-collection minimart.${COLLECTION}; then
        echo "Failed create of collection ${COLLECTION}"
        exit 1
    fi
done

# expressmart
for COLLECTION in "beer" "wine" "meat" "fruit" "vegetable" "dairy" "sweets";
do
    if ! ${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${TARGET_BUCKET} --create-collection expressmart.${COLLECTION}; then
        echo "Failed create of collection ${COLLECTION}"
        exit 1
    fi
done

# supermarket
for COLLECTION in "beer" "wine" "meat" "fruit" "vegetable" "dairy" "sweets" "household";
do
    if ! ${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${TARGET_BUCKET} --create-collection supermarket.${COLLECTION}; then
        echo "Failed create of collection ${COLLECTION}"
        exit 1
    fi
done

# megamart
for COLLECTION in "beer" "wine" "meat" "fruit" "vegetable" "dairy" "sweets" "electricals" "household";
do
    if ! ${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${TARGET_BUCKET} --create-collection megamart.${COLLECTION}; then
        echo "Failed create of collection ${COLLECTION}"
        exit 1
    fi
done

exit 0