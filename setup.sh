#!/bin/bash
pushd ${PWD}
git clone git@github.com:couchbase/kv_engine.git
#git clone git@github.com:couchbaselabs/pydcp.git
mkdir -p go/src
cd go/src
git clone git@github.com:jimwwalker/gocbcore.git
cd gocbcore
git checkout collections_dcp_streams
popd

# Compile the go dcp client
GOPATH=${PWD}/go/
go build -o go_dcp/dcp_stream go_dcp/dcp_stream.go