#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This script is used to update the telemetry folder in the current directory from git.

pushd `dirname $0` > /dev/null

git clone --depth 1 git@github.com:AutoMQ/automq-for-kafka.git automq-for-kafka-tmp
rm -rf ./telemetry
mv automq-for-kafka-tmp/docker/telemetry .
rm -rf automq-for-kafka-tmp

popd > /dev/null
