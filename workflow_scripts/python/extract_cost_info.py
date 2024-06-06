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

import re
import os
import sys

with open('/tmp/aws-cost.txt', 'r') as file:
    output = file.read()

print("File content:")
print(output)

pattern = re.compile(r'┃\s*main\s*┃([^┃]*)┃([^┃]*)┃([^┃]*)┃')
match = pattern.search(output)

print(f"Match: {match}")

if match:
    baseline_cost_str = re.sub(r'[^\d.]', '', match.group(1))
    usage_cost_str = re.sub(r'[^\d.]', '', match.group(2))
    total_cost_str = re.sub(r'[^\d.]', '', match.group(3))

#     decrease client cost 5*92.93 USD = 464.65 (decrease 5 client's cost)
    baseline_cost = float(baseline_cost_str) - 464.65
    usage_cost = float(usage_cost_str)
    total_cost = float(total_cost_str) - 464.65

    print(f"Baseline cost: ${baseline_cost}")
    print(f"Usage cost: ${usage_cost}")
    print(f"Total cost: ${total_cost}")

    github_output = os.getenv('GITHUB_OUTPUT', 'output.txt')
    streaming_provider = os.environ.get('STREAMING_PROVIDER', 'default_value')
    with open(github_output, 'a') as output_file:
        output_file.write(f'baseline_cost_{streaming_provider}={baseline_cost}\n')
        output_file.write(f'usage_cost_{streaming_provider}={usage_cost}\n')
        output_file.write(f'total_cost_{streaming_provider}={total_cost}\n')
else:
    print("Can't extract cost info")
    sys.exit(1)

