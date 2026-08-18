#!/usr/bin/env bash
# shellcheck disable=SC2182,SC2183
# Justification: fixture reuses formats and omits args to match Bash printf
# Comparison sample: Bash builtin printf usage
# Paired with printf-builtin.c; 0006 compiles printf-builtin beside this script

printf "Hello World!\n"
printf "hello"
printf " after no-nl\n"
printf "%s\n" hello
printf "%s " a b c
printf "\n"
printf "%s-%s\n" only
printf "%d %d\n" 5
printf "a\tb\nc\n"
printf "%b\n" "a\tb"
printf "%s\n" "a\tb"
printf "%q\n" "hello world"
printf "%q\n" ""
printf "%q\n" "a\$b'c"
printf -- "-%s-\n" x
printf "%s\n" -- -v
printf "\101\n"
printf "\x41\n"
printf "\u0041\U00000042\n"
printf "%bEND\n" "hi\cXX"
printf "%5s|\n" hi
printf "%-5s|\n" hi
printf "%d %i %u %o %x %X\n" 42 42 42 42 42 42
printf "%.2f %.2e\n" 3.14159 3.14159
printf "%c\n" ABC
printf "%05d\n" 12
printf "%+d\n" 12
printf "% d\n" 12
printf "%#x %#o\n" 16 8
printf "%*s|\n" 5 hi
printf "%.*s\n" 3 hello
printf "%%s\n"
printf "%s=%d " a 1 b 2
printf "\n"
printf ""
printf "%s\n" -n
printf "%Q\n" "hello world"
printf "%.3Q\n" "hello"
printf "%.3q\n" "hello"
printf "%b\n" "\0101"
printf "%b\n" "\x41"
printf "X"
printf "%d\n" 0x10
printf "[%s]\n" "  x  "
printf "%bX\n" "\x00"
printf "%q\n" "a b	c"
printf "%q\n" "*?[]"
printf "%q\n" -n
printf "%q\n" abc123
printf "%q\n" foo_bar
printf "%q\n" /tmp/foo
printf "%q\n" a=b
printf "%q\n" 'a`b'
printf "%q\n" 'a\b'
printf "%q\n" "~"
printf "%q\n" "#comment"
printf "%q\n" "a!b"
printf "%q\n" "(x)"
printf "%q\n" "a;b"
printf "%q\n" "a|b"
printf "%q\n" "a&b"
printf "%q\n" "a<b>c"
printf "%q\n" "a,b"
printf "%q\n" "a{b}"
printf "%q\n" "a^b"
printf "%q\n" "+x"
printf "%q\n" "a:b"
printf "%10q|\n" hi
printf "%b leftover\n" "x\cY"
printf "x\cY\n"
printf "\101\102\n"
printf "\7X\n"
printf "\0101\n"
printf "%d\n" -5
printf "%d\n" 010
printf "%g %G\n" 0.0000123 1234567
printf "%+d\n" -3
printf "%+05d\n" 3
printf "%*s|\n" -5 hi
printf "%*.*s|\n" 6 3 hello
TZ=UTC printf "%(%Y-%m-%d %H:%M:%S)T\n" 0
TZ=UTC printf "%(%H:%M)T\n" 0
printf "%s\n" -- x
printf -- "--\n"
printf "%%b\n" x
printf "%0s|\n" hi
printf "%.0s|\n" hi
printf "%.0d\n" 0
printf "%#o\n" 0
printf "%b" "\101"
printf "%b" "\41"
printf "%b" "\7"
printf "%b" "\8"
printf "\n"
printf "%s-%s|" a b c d e
printf "\n"
printf "%'d\n" 1234567
printf "%s%n%s\n" a b
printf "%c\n" ""
printf "[%s]\n"
printf "[%b]\n"
printf "[%q]\n"
printf "%b\n" "\q\8"
printf "\q\8\n"
printf "%b" "\e\E"
printf "\e\E"
printf "%b" "\0A"
printf "\0A"
printf "%b" "\0377"
printf "\n"
printf "%d\n" +12
printf "%d\n" +0x10
printf "%d\n" 0X10
printf "%f\n" 1
printf "%g\n" 1
printf "%e\n" 1
printf "A%bB%bC\n" "x\cy" "z"
printf "%b\n" "\u0041\U0001F600"
printf "\u00A9\n"
printf "\U0001F600\n"
printf "%ld\n" 123
printf "%hhd\n" 300
printf "%Lf\n" 1.5
printf "%jd\n" 99
printf "%zd\n" 99
printf "%td\n" 99
printf "%lld\n" 99
printf "%*d\n" 5 12
printf "end\\"
printf "\n"
printf "%b" "end\\"
printf "\n"
printf "Usage: %s [%s]\n" demo options
printf "%-10s %04d\n" item 7
printf "%s\n" ""
printf "%b\n" ""
printf "col1\tcol2\n"
printf "%s %s %s\n" one two three
printf "  leading spaces\n"
printf "%s\n" "  leading spaces"
printf "%#x\n" 0
printf "%i\n" 0
printf "%o\n" 8
printf "%X\n" 255
printf "%.4s\n" toolong
printf "%4.2s|\n" hello
printf "%-4.2s|\n" hello
printf "%s" "no-nl-end"
printf "\n"
printf "%q\n" "   "
printf "%q\n" "\$HOME"
printf "%b\n" "foo\cbar"
printf "%s\n" "foo\cbar"
