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

red='\033[31m'
green='\033[32m'
blue='\033[34m'

# Color-echo. 1 = message, 2 = color
function cecho()  {
    echo -ne "$2"
    echo -e "$1\033[0m"
}

TEMP_DIRS=()
function mktemp_tracked() {
    local __resultvar=$1
    local __tmp=$(mktemp)
    TEMP_DIRS+=($__tmp)
    eval $__resultvar="'$__tmp'"
}

PIDS=()
function register_pid() {
    local __resultvar=$1
    local __pid=$!
    PIDS+=($__pid)
    eval $__resultvar="'$__pid'"
}

function cleanup() {
    for i in "${TEMP_DIRS[@]}"
    do
        rm $i
    done
    for i in "${PIDS[@]}"
    do
        kill $i 2> /dev/null > /dev/null
    done
    exit 0
}

function expect_eq() {
    if [ "$1" == "$2" ]; then
        return
    fi
    cecho "$3" $red
}

function expect_ne() {
    if [ "$1" != "$2" ]; then
        return
    fi
    cecho "$3" $red
}

function assert_eq() {
    if [ "$1" == "$2" ]; then
        return
    fi
    cecho "$3" $red
    exit 1
}

function assert_ne() {
    if [ "$1" != "$2" ]; then
        return
    fi
    cecho "$3" $red
    exit 1
}

function assert_grep() {
    grep -q "$1" $2
    assert_eq $? 0 "Failed to find $1 in $2"
}

function assert_not_grep() {
    grep -q "$1" $2
    assert_eq $? 1 "Failed: Found $1 in $2"
}

trap cleanup INT EXIT