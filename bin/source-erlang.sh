#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing,
#   software distributed under the License is distributed on an
#   "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#   KIND, either express or implied.  See the License for the
#   specific language governing permissions and limitations
#   under the License.

# Build Erlang from source on systems where desired package
# versions are not available
#
# While these scripts are primarily written to support building CI
# Docker images, they can be used on any workstation to install a
# suitable build environment.

# stop on error
set -e

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  echo "Sorry, this script must be run as root."
  echo "Try: sudo $0 $*"
  exit 1
fi

# This works if we're not called through a symlink
# otherwise, see https://stackoverflow.com/questions/59895/
SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. ${SCRIPTPATH}/detect-os.sh

redhats='(rhel|centos|fedora)'
debians='(debian|ubuntu)'

# Install per-distro dependencies according to:
#  http://docs.basho.com/riak/1.3.0/tutorials/installation/Installing-Erlang/
if [[ ${ID} =~ ${redhats} ]]; then
    yum install git gcc glibc-devel make ncurses-devel openssl-devel autoconf
elif [[ ${ID} =~ ${debians} ]]; then
    apt-get update
    apt-get install -y git build-essential autoconf libncurses5-dev openssl libssl-dev xsltproc
else
  echo "Sorry, we don't support this Linux (${ID}) yet."
  exit 1
fi

# Pull down and checkout the requested Erlang version
git clone https://github.com/erlang/otp.git
cd otp
git checkout OTP-${ERLANGVERSION} -b local-OTP-${ERLANGVERSION}

# Configure Erlang - skip building things we don't want or need
./otp_build autoconf
./otp_build configure --without-javac

if [ -d lib/gs ]; then
    echo "skipping gs" > lib/gs/SKIP
fi

if [ -d lib/jinterface ]; then
    echo "skipping jinterface" > lib/jinterface/SKIP
fi

if [ -d lib/ic ]; then
    echo "skipping ic" > lib/ic/SKIP

    SKIP="orber cosTransactions cosEvent cosTime cosNotification \
        cosProperty cosFileTransfer cosEventDomain"
    for pkg in $SKIP; do
        if [ -d lib/$pkg ]; then
            echo "skipping $pkg" > lib/$pkg/SKIP
        fi
    done
fi

if [ -d lib/wx ]; then
    echo "skipping wx" > lib/wx/SKIP

    SKIP="debugger observer et"
    for pkg in $SKIP; do
        if [ -d lib/$pkg ]; then
            echo "skipping $pkg" > lib/$pkg/SKIP
        fi
    done
fi

# Build Erlang
make -j $(nproc)

# Install Erlang
make install

# Clean-up
cd -
rm -rf otp

if [[ ${ID} =~ ${redhats} ]]; then
    yum clean all
elif [[ ${ID} =~ ${debians} ]]; then
    apt-get clean
fi
