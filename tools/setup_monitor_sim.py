#!/usr/bin/env python3
"""Install a pinned, unprivileged Linux x86-64 Verilator for UART integration tests."""
import hashlib,platform,shutil,subprocess,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
URL='https://archive.ubuntu.com/ubuntu/pool/universe/v/verilator/verilator_5.020-1_amd64.deb'
SHA='bb74ca8c32c73eb903ee91da64c8b58cfbe095c229967a95782108afb67bb3ca'
def main():
    if platform.system()!='Linux' or platform.machine() not in ('x86_64','AMD64'):
        raise SystemExit('Install Verilator with timing support for your platform and set VERILATOR.')
    for command in ('dpkg-deb','g++','make','perl'):
        if not shutil.which(command):raise SystemExit(f'Missing prerequisite: {command}')
    root=ROOT/'.tools/monitor-verilator';root.mkdir(parents=True,exist_ok=True);archive=root/'package.deb'
    if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest()!=SHA:
        with urllib.request.urlopen(URL,timeout=60) as source:archive.write_bytes(source.read())
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=SHA:raise SystemExit('Verilator archive checksum mismatch')
    subprocess.run(['dpkg-deb','-x',str(archive),str(root)],check=True)
    share=root/'usr/share/verilator';binary=share/'verilator_bin'
    if not binary.exists():binary.symlink_to('../../bin/verilator_bin')
    wrapper=root/'verilator'
    # Absolute paths resolved from wrapper location; shell never interpolates user input.
    wrapper.write_text('#!/bin/sh\nbase=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexport VERILATOR_ROOT="$base/usr/share/verilator"\nexec "$base/usr/bin/verilator" "$@"\n');wrapper.chmod(0o755)
    subprocess.run([str(wrapper),'--version'],check=True)
    print('Run: make test-monitor VERILATOR=.tools/monitor-verilator/verilator')
if __name__=='__main__':main()
