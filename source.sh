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

# These variables are used by the test script and may require tuning

# CTS = Collection Testing Scripts
CTS_TOP_DIR=`pwd`

# CTS_CB variables for the couchbase tools and cluster
CTS_CB_BIN=/opt/couchbase/bin
CTS_CB_BIN=/Users/jimwalker/Code/couchbase/source/install/bin/
CTS_CB_NODE=127.0.0.1
CTS_CB_DATA_PORT=12000
CTS_CB_ADMIN_PORT=9000
CTS_CB_USER=Administrator
CTS_CB_PASSWD=asdasd

# We will run pydcp and kv_engine sourced code
CTS_PYDCP=${CTS_TOP_DIR}/pydcp/
CTS_BIN=${CTS_TOP_DIR}/bin
CTS_KV_ENGINE=${CTS_TOP_DIR}/kv_engine
CTS_LIB=${CTS_TOP_DIR}/lib

# python under kv_engine is python3
CTS_PYTHON3=~/Code/couchbase/source/build/tlm/python/miniconda3-4.6.14/bin/python
# Update python path to know about our mc_bin_client
PYTHONPATH=${CTS_KV_ENGINE}/engines/ep/management/:${PYTHONPATH}

# pydcp is not python3
CTS_PYTHON=`which python`

export CTS_TOP_DIR
export CTS_CB_BIN
export CTS_CB_NODE
export CTS_CB_DATA_PORT
export CTS_CB_ADMIN_PORT
export CTS_CB_USER
export CTS_CB_PASSWD
export CTS_PYDCP
export CTS_BIN
export CTS_KVENGINE
export CTS_PYTHON3
export CTS_PYTHON
export PYTHONPATH
