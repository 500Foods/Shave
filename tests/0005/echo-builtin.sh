#!/usr/bin/env bash
# Comparison sample: Bash builtin echo usage
# shave/shave writes echo-builtin.c and echo-builtin beside this script

echo "Hello World!"
echo hello world
echo -n "no newline"
echo " after -n"
echo -e 'col1\tcol2'
echo -E 'leave\talone'
echo -- -n
echo -n -e 'hi\cXX'
echo -e '\x41\x42'
echo -e '\u0041\U00000042'
echo
echo ""
echo a "" b
echo -n -n -n stacked
echo hello -n
echo -x not_an_option
echo -
echo -e 'a\tb\nc'
echo -e 'foo\cbar'
echo -e '\\ and \q and \8'
echo one two three
echo "  leading spaces"
echo -eeen '\x41'
echo -e -E 'a\tb'
echo -E -e 'a\tb'
echo -enE 'a\tb'
echo -e '\0101'
echo -e '\e[0mreset'
echo -ne "partial"
echo
echo -e '\c'
echo -n
echo -e '\x4G'
echo -e 'end\'
echo -nenenene hello
echo -e '\012\011end'
echo "Starting backup"
echo "- source: /var/data"
echo "- dest: /mnt/backup"
echo
echo -n "Progress: "
echo "done"
echo -e 'path:\t/tmp/foo'
echo -e '\a\b\f\n\r\t\v'
echo -e '\U0001F600'
echo -e '\0A'
echo -e '\x00X'
echo -e '\u00A9'
echo Usage: demo '[options]'
echo -n
echo -e
echo -E
echo -n -e -E
echo -e 'trailing\\'
