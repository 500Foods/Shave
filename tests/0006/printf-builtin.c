/*
 * printf-builtin.c - C comparison sample matching tests/0006/printf-builtin.sh
 *
 * CHANGELOG
 * 1.2.0 - 2026-08-18 - Shave compiler emits tests/0006/printf-builtin beside this source
 * 1.1.0 - 2026-08-18 - Live beside printf-builtin.sh in tests/0006
 * 1.0.0 - 2026-08-18 - Initial C fixture for bash printf comparison
 */

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include "shave_printf_builtin.h"

#include <locale.h>
#include <stdlib.h>
#include <time.h>

int main(void)
{
    int status = 0;

    setlocale(LC_ALL, "");

    status |= shave_printf_builtin(2, (char *[]){"printf", "Hello World!\n"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "hello"});
    status |= shave_printf_builtin(2, (char *[]){"printf", " after no-nl\n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%s\n", "hello"});
    status |= shave_printf_builtin(5, (char *[]){"printf", "%s ", "a", "b", "c"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%s-%s\n", "only"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%d %d\n", "5"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "a\tb\nc\n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b\n", "a\\tb"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%s\n", "a\\tb"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "hello world"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", ""});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "a$b'c"});
    status |= shave_printf_builtin(4, (char *[]){"printf", "--", "-%s-\n", "x"});
    status |= shave_printf_builtin(4, (char *[]){"printf", "%s\n", "--", "-v"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\\101\\n"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\\x41\\n"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\\u0041\\U00000042\\n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%bEND\n", "hi\\cXX"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%5s|\n", "hi"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%-5s|\n", "hi"});
    status |= shave_printf_builtin(8, (char *[]){"printf", "%d %i %u %o %x %X\n", "42", "42", "42", "42", "42", "42"});
    status |= shave_printf_builtin(4, (char *[]){"printf", "%.2f %.2e\n", "3.14159", "3.14159"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%c\n", "ABC"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%05d\n", "12"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%+d\n", "12"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "% d\n", "12"});
    status |= shave_printf_builtin(4, (char *[]){"printf", "%#x %#o\n", "16", "8"});
    status |= shave_printf_builtin(4, (char *[]){"printf", "%*s|\n", "5", "hi"});
    status |= shave_printf_builtin(4, (char *[]){"printf", "%.*s\n", "3", "hello"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "%%s\n"});
    status |= shave_printf_builtin(6, (char *[]){"printf", "%s=%d ", "a", "1", "b", "2"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\n"});
    status |= shave_printf_builtin(2, (char *[]){"printf", ""});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%s\n", "-n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%Q\n", "hello world"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%.3Q\n", "hello"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%.3q\n", "hello"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b\n", "\\0101"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b\n", "\\x41"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "X"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%d\n", "0x10"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "[%s]\n", "  x  "});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%bX\n", "\\x00"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "a b\tc"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "*?[]"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "-n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "abc123"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "foo_bar"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "/tmp/foo"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "a=b"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "a`b"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "a\\b"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "~"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "#comment"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "a!b"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "(x)"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "a;b"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "a|b"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "a&b"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "a<b>c"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "a,b"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "a{b}"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "a^b"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "+x"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "a:b"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%10q|\n", "hi"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b leftover\n", "x\\cY"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "x\\cY\\n"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\\101\\102\\n"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\\7X\\n"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\\0101\\n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%d\n", "-5"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%d\n", "010"});
    status |= shave_printf_builtin(4, (char *[]){"printf", "%g %G\n", "0.0000123", "1234567"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%+d\n", "-3"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%+05d\n", "3"});
    status |= shave_printf_builtin(4, (char *[]){"printf", "%*s|\n", "-5", "hi"});
    status |= shave_printf_builtin(5, (char *[]){"printf", "%*.*s|\n", "6", "3", "hello"});
    {
        const char *old_tz;
        old_tz = getenv("TZ");
        setenv("TZ", "UTC", 1);
        tzset();
        status |= shave_printf_builtin(3, (char *[]){"printf", "%(%Y-%m-%d %H:%M:%S)T\n", "0"});
        status |= shave_printf_builtin(3, (char *[]){"printf", "%(%H:%M)T\n", "0"});
        if (old_tz != NULL) {
            setenv("TZ", old_tz, 1);
        } else {
            unsetenv("TZ");
        }
        tzset();
    }
    status |= shave_printf_builtin(4, (char *[]){"printf", "%s\n", "--", "x"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "--", "--\n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%%b\n", "x"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%0s|\n", "hi"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%.0s|\n", "hi"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%.0d\n", "0"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%#o\n", "0"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b", "\\101"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b", "\\41"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b", "\\7"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b", "\\8"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\n"});
    status |= shave_printf_builtin(7, (char *[]){"printf", "%s-%s|", "a", "b", "c", "d", "e"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%'d\n", "1234567"});
    status |= shave_printf_builtin(4, (char *[]){"printf", "%s%n%s\n", "a", "b"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%c\n", ""});
    status |= shave_printf_builtin(2, (char *[]){"printf", "[%s]\n"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "[%b]\n"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "[%q]\n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b\n", "\\q\\8"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\\q\\8\\n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b", "\\e\\E"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\\e\\E"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b", "\\0A"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\\0A"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b", "\\0377"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%d\n", "+12"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%d\n", "+0x10"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%d\n", "0X10"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%f\n", "1"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%g\n", "1"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%e\n", "1"});
    status |= shave_printf_builtin(4, (char *[]){"printf", "A%bB%bC\n", "x\\cy", "z"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b\n", "\\u0041\\U0001F600"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\\u00A9\\n"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\\U0001F600\\n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%ld\n", "123"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%hhd\n", "300"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%Lf\n", "1.5"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%jd\n", "99"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%zd\n", "99"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%td\n", "99"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%lld\n", "99"});
    status |= shave_printf_builtin(4, (char *[]){"printf", "%*d\n", "5", "12"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "end\\"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b", "end\\"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\n"});
    status |= shave_printf_builtin(4, (char *[]){"printf", "Usage: %s [%s]\n", "demo", "options"});
    status |= shave_printf_builtin(4, (char *[]){"printf", "%-10s %04d\n", "item", "7"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%s\n", ""});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b\n", ""});
    status |= shave_printf_builtin(2, (char *[]){"printf", "col1\tcol2\n"});
    status |= shave_printf_builtin(5, (char *[]){"printf", "%s %s %s\n", "one", "two", "three"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "  leading spaces\n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%s\n", "  leading spaces"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%#x\n", "0"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%i\n", "0"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%o\n", "8"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%X\n", "255"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%.4s\n", "toolong"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%4.2s|\n", "hello"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%-4.2s|\n", "hello"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%s", "no-nl-end"});
    status |= shave_printf_builtin(2, (char *[]){"printf", "\n"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "   "});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%q\n", "$HOME"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%b\n", "foo\\cbar"});
    status |= shave_printf_builtin(3, (char *[]){"printf", "%s\n", "foo\\cbar"});

    return status == 0 ? 0 : 1;
}
