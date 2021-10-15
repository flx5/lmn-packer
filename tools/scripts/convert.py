import subprocess
import json
from string import Template
import argparse

parser = argparse.ArgumentParser(description='Convert VM template')
parser.add_argument('-d', '--disks', nargs='+', required=True, help='the disks to attach')
parser.add_argument('-t', '--template', required=True, help='the template file to use')
parser.add_argument('-o', '--output', required=True, help='the file to write the substituted template to')

args = parser.parse_args()

mapping = dict()

for i, disk in enumerate(args.disks):
   process_result = subprocess.run(["qemu-img", "info", disk, "--output", "json"], check=True, capture_output=True)
   result = json.loads(process_result.stdout)
   mapping['virtual_size_' + str(i)] = result['virtual-size']
   mapping['physical_size_' + str(i)] = result['actual-size']


with open(args.template, 'r') as f:
   template = Template(f.read())


with open(args.output, 'w') as f:
   f.write(template.substitute(mapping))
