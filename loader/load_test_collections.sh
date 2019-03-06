#!/bin/bash
CTS_CB_BUCKET=$1

for SCOPE in  "shop" "minimart" "expressmart" "supermarket" "megamart";
do
    if ! ${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${CTS_CB_BUCKET} --create-scope ${SCOPE}; then
        echo "Failed create of scope ${SCOPE}"
        exit 1
    fi
done

# default
for COLLECTION in "beer" "wine" "meat" "fruit" "vegetable" "dairy" "sweets" "electricals" "household";
do
    if ! ${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${CTS_CB_BUCKET} --create-collection _default.${COLLECTION}; then
        echo "Failed create of collection ${COLLECTION}"
        exit 1
    fi
done

# shop
for COLLECTION in "beer" "wine" "sweets";
do
    if ! ${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${CTS_CB_BUCKET} --create-collection shop.${COLLECTION}; then
        echo "Failed create of collection ${COLLECTION}"
        exit 1
    fi
done

# minimart
for COLLECTION in "beer" "wine" "dairy" "sweets";
do
    if ! ${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${CTS_CB_BUCKET} --create-collection minimart.${COLLECTION}; then
        echo "Failed create of collection ${COLLECTION}"
        exit 1
    fi
done

# expressmart
for COLLECTION in "beer" "wine" "meat" "fruit" "vegetable" "dairy" "sweets";
do
    if ! ${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${CTS_CB_BUCKET} --create-collection expressmart.${COLLECTION}; then
        echo "Failed create of collection ${COLLECTION}"
        exit 1
    fi
done

# supermarket
for COLLECTION in "beer" "wine" "meat" "fruit" "vegetable" "dairy" "sweets" "household";
do
    if ! ${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${CTS_CB_BUCKET} --create-collection supermarket.${COLLECTION}; then
        echo "Failed create of collection ${COLLECTION}"
        exit 1
    fi
done

# megamart
for COLLECTION in "beer" "wine" "meat" "fruit" "vegetable" "dairy" "sweets" "electricals" "household";
do
    if ! ${CTS_CB_BIN}/couchbase-cli collection-manage -c ${CTS_CB_NODE} -u ${CTS_CB_USER} -p ${CTS_CB_PASSWD} --bucket ${CTS_CB_BUCKET} --create-collection megamart.${COLLECTION}; then
        echo "Failed create of collection ${COLLECTION}"
        exit 1
    fi
done

exit 0