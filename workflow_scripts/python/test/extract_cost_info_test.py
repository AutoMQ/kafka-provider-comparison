import re
import os
import sys

with open('automq-cost-info.txt', 'r') as file:
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

    try:
        baseline_cost = float(baseline_cost_str) - 286.54
        usage_cost = float(usage_cost_str)
        total_cost = float(total_cost_str)- 286.54
    except ValueError as e:
        print(f"Error converting to float: {e}")
        sys.exit(1)

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