#!/usr/bin/env python3
import glob
import pexpect

modules = []
for file in glob.glob('drivers/*/modules'):
    with open(file, 'r') as f:
        lines = f.readlines()
        for line in lines:
            modules.append(line.strip())
modules.sort()
print('Found {} module(s): {}'.format(len(modules), ', '.join(modules)))
assert len(modules) > 0, 'no modules to test'

cmd = 'bash -c "TMPDIR=$(mktemp -d) output/images/vmlinux mem=32M initrd=output/images/rootfs_final.cpio noreboot"'
vm_log = open('output/tests/vm.dmesg', 'w')
vm = pexpect.spawn(cmd, encoding='utf-8', logfile=vm_log)

vm.expect('Linux version')
vm.expect('Unpacking initramfs')
vm.expect('TAP version 14')
vm.expect('Run /init as init process')
vm.expect('login:')
vm.sendline('root')
vm.expect('#')

results = {}
for test in modules:
    test_dmesg = 'output/tests/{}.dmesg'.format(test)
    test_parse = open('output/tests/{}.parse'.format(test), 'w')

    vm.sendline('time insmod $(find /lib/modules/ -name {}.ko)'.format(test))
    vm.expect('real\t')
    output = vm.before.splitlines()[1:]
    vm.expect('#')
    testsuites = [line for line in output if 'Subtest:' in line]
    header = ['TAP version 14\n', '1..{}\n'.format(len(testsuites))]

    vm.sendline('echo $?')
    vm.expect('#')
    result = int(vm.before.splitlines()[1])
    if result != 0:
        results[test] = [1, 'insmod failed']
        continue

    raw = ''.join(header) + '\n'.join(output)
    with open(test_dmesg, 'w') as f:
        f.write(raw)
    print(raw)

    cmd = 'bash -c "cd linux && ./tools/testing/kunit/kunit.py parse ../{}"'.format(test_dmesg)
    parser = pexpect.spawn(cmd, encoding='utf-8', logfile=test_parse)
    parser.expect(pexpect.EOF)
    output = parser.before
    print(output)

    if ' 0 failed. 0 crashed.' not in output:
        results[test] = [1, 'tests failed']
        continue

    results[test] = [0, 'tests passed']

vm.sendline('reboot')
vm.expect(pexpect.EOF)

print('Summary:')
total_failed = 0
for test, result in results.items():
    print('  {:<40}: {}'.format(test, result[1]))
    total_failed += result[0]
print('total: {} tests failed'.format(total_failed))

assert total_failed == 0, 'tests failed'
