from proxmoxer import ProxmoxAPI
import argparse
import os
import sys

parser = argparse.ArgumentParser()
parser.add_argument("action", choices=["start", "shutdown"])
parser.add_argument("--node", required=True)
parser.add_argument("--vm", required=True, type=int)

args = parser.parse_args()

host = os.getenv('PROXMOX_HOST')
user = os.getenv('PROXMOX_USER')
password = os.getenv('PROXMOX_PASSWORD')

if host == None or user == None or password == None:
  print("Make sure that PROXMOX_HOST, PROXMOX_USER and PROXMOX_PASSWORD environment variables exist.")
  sys.exit(1)

proxmox = ProxmoxAPI(host, user=user,
                     password=password, verify_ssl=False)
                     
node = proxmox.nodes(args.node)

vm = node.qemu(args.vm)

if args.action == "start":
  vm.status.start.post()
else:
  vm.status.shutdown.post()
