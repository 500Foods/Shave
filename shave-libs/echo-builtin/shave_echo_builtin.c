/*
 * shave_echo_builtin.c - In-process Bash builtin echo
 *
 * CHANGELOG
 * 1.0.1 - 2026-08-18 - Const-qualify internal argv helper
 * 1.0.0 - 2026-08-18 - Initial Bash-compatible echo builtin library
 */

#include "shave_echo_builtin.h"

#include <stddef.h>

struct shave_echo_writer {
    FILE *out;
    int err;
    int stop;
};

static int shave_echo_is_hex(unsigned char c)
{
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

static unsigned int shave_echo_hex_val(unsigned char c)
{
    if (c >= '0' && c <= '9') {
        return (unsigned int)(c - '0');
    }
    if (c >= 'a' && c <= 'f') {
        return (unsigned int)(c - 'a' + 10);
    }
    return (unsigned int)(c - 'A' + 10);
}

static int shave_echo_is_option(const char *text)
{
    const char *cursor;

    if (text == NULL || text[0] != '-' || text[1] == '\0') {
        return 0;
    }
    cursor = text + 1;
    while (*cursor != '\0') {
        if (*cursor != 'n' && *cursor != 'e' && *cursor != 'E') {
            return 0;
        }
        cursor++;
    }
    return 1;
}

static void shave_echo_write_bytes(struct shave_echo_writer *writer, const void *data, size_t length)
{
    if (writer->err != 0 || writer->stop != 0 || length == 0) {
        return;
    }
    if (fwrite(data, 1, length, writer->out) != length) {
        writer->err = 1;
    }
}

static void shave_echo_write_byte(struct shave_echo_writer *writer, unsigned char value)
{
    shave_echo_write_bytes(writer, &value, 1);
}

static void shave_echo_write_utf8(struct shave_echo_writer *writer, unsigned long codepoint)
{
    unsigned char buf[6];
    int count = 0;

    if (codepoint <= 0x7FUL) {
        buf[0] = (unsigned char)codepoint;
        count = 1;
    } else if (codepoint <= 0x7FFUL) {
        buf[0] = (unsigned char)(0xC0U | (codepoint >> 6));
        buf[1] = (unsigned char)(0x80U | (codepoint & 0x3FUL));
        count = 2;
    } else if (codepoint <= 0xFFFFUL) {
        buf[0] = (unsigned char)(0xE0U | (codepoint >> 12));
        buf[1] = (unsigned char)(0x80U | ((codepoint >> 6) & 0x3FUL));
        buf[2] = (unsigned char)(0x80U | (codepoint & 0x3FUL));
        count = 3;
    } else if (codepoint <= 0x1FFFFFUL) {
        buf[0] = (unsigned char)(0xF0U | (codepoint >> 18));
        buf[1] = (unsigned char)(0x80U | ((codepoint >> 12) & 0x3FUL));
        buf[2] = (unsigned char)(0x80U | ((codepoint >> 6) & 0x3FUL));
        buf[3] = (unsigned char)(0x80U | (codepoint & 0x3FUL));
        count = 4;
    } else if (codepoint <= 0x3FFFFFFUL) {
        buf[0] = (unsigned char)(0xF8U | (codepoint >> 24));
        buf[1] = (unsigned char)(0x80U | ((codepoint >> 18) & 0x3FUL));
        buf[2] = (unsigned char)(0x80U | ((codepoint >> 12) & 0x3FUL));
        buf[3] = (unsigned char)(0x80U | ((codepoint >> 6) & 0x3FUL));
        buf[4] = (unsigned char)(0x80U | (codepoint & 0x3FUL));
        count = 5;
    } else if (codepoint <= 0x7FFFFFFFUL) {
        buf[0] = (unsigned char)(0xFCU | (codepoint >> 30));
        buf[1] = (unsigned char)(0x80U | ((codepoint >> 24) & 0x3FUL));
        buf[2] = (unsigned char)(0x80U | ((codepoint >> 18) & 0x3FUL));
        buf[3] = (unsigned char)(0x80U | ((codepoint >> 12) & 0x3FUL));
        buf[4] = (unsigned char)(0x80U | ((codepoint >> 6) & 0x3FUL));
        buf[5] = (unsigned char)(0x80U | (codepoint & 0x3FUL));
        count = 6;
    } else {
        return;
    }
    shave_echo_write_bytes(writer, buf, (size_t)count);
}

static const char *shave_echo_arg(char *const *const argv, int index)
{
    if (argv[index] == NULL) {
        return "";
    }
    return argv[index];
}

static void shave_echo_write_interpreted(struct shave_echo_writer *writer, const char *text)
{
    const unsigned char *cursor;

    cursor = (const unsigned char *)text;
    while (*cursor != '\0' && writer->stop == 0) {
        unsigned char current;
        unsigned char next;
        unsigned int value;
        unsigned long codepoint;
        int digits;
        int max_digits;
        unsigned char kind;

        current = *cursor;
        if (current != '\\') {
            shave_echo_write_byte(writer, current);
            cursor++;
            continue;
        }

        cursor++;
        if (*cursor == '\0') {
            shave_echo_write_byte(writer, '\\');
            break;
        }

        next = *cursor;
        switch (next) {
        case 'a':
            shave_echo_write_byte(writer, '\a');
            cursor++;
            break;
        case 'b':
            shave_echo_write_byte(writer, '\b');
            cursor++;
            break;
        case 'c':
            writer->stop = 1;
            cursor++;
            break;
        case 'e':
        case 'E':
            shave_echo_write_byte(writer, 0x1BU);
            cursor++;
            break;
        case 'f':
            shave_echo_write_byte(writer, '\f');
            cursor++;
            break;
        case 'n':
            shave_echo_write_byte(writer, '\n');
            cursor++;
            break;
        case 'r':
            shave_echo_write_byte(writer, '\r');
            cursor++;
            break;
        case 't':
            shave_echo_write_byte(writer, '\t');
            cursor++;
            break;
        case 'v':
            shave_echo_write_byte(writer, '\v');
            cursor++;
            break;
        case '\\':
            shave_echo_write_byte(writer, '\\');
            cursor++;
            break;
        case '0':
            value = 0;
            digits = 0;
            while (digits < 4 && *cursor >= '0' && *cursor <= '7') {
                value = (value << 3) | (unsigned int)(*cursor - '0');
                cursor++;
                digits++;
            }
            shave_echo_write_byte(writer, (unsigned char)value);
            break;
        case 'x':
            cursor++;
            if (!shave_echo_is_hex(*cursor)) {
                shave_echo_write_byte(writer, '\\');
                shave_echo_write_byte(writer, 'x');
                break;
            }
            value = shave_echo_hex_val(*cursor);
            cursor++;
            if (shave_echo_is_hex(*cursor)) {
                value = (value << 4) | shave_echo_hex_val(*cursor);
                cursor++;
            }
            shave_echo_write_byte(writer, (unsigned char)value);
            break;
        case 'u':
        case 'U':
            kind = next;
            max_digits = (kind == 'u') ? 4 : 8;
            cursor++;
            if (!shave_echo_is_hex(*cursor)) {
                shave_echo_write_byte(writer, '\\');
                shave_echo_write_byte(writer, kind);
                break;
            }
            codepoint = 0;
            digits = 0;
            while (digits < max_digits && shave_echo_is_hex(*cursor)) {
                codepoint = (codepoint << 4) | shave_echo_hex_val(*cursor);
                cursor++;
                digits++;
            }
            shave_echo_write_utf8(writer, codepoint);
            break;
        default:
            shave_echo_write_byte(writer, '\\');
            shave_echo_write_byte(writer, next);
            cursor++;
            break;
        }
    }
}

static int shave_echo_emit(FILE *out, int argc, char *const argv[], int interpret)
{
    struct shave_echo_writer writer;
    int suppress_newline = 0;
    int index = 1;
    int first_operand = 1;

    if (out == NULL) {
        return 1;
    }
    if (argc > 0 && argv == NULL) {
        return 1;
    }

    writer.out = out;
    writer.err = 0;
    writer.stop = 0;

    if (argv != NULL) {
        while (index < argc && shave_echo_is_option(argv[index])) {
            const char *flag = argv[index] + 1;
            while (*flag != '\0') {
                if (*flag == 'n') {
                    suppress_newline = 1;
                } else if (*flag == 'e') {
                    interpret = 1;
                } else if (*flag == 'E') {
                    interpret = 0;
                }
                flag++;
            }
            index++;
        }
    }

    while (argv != NULL && index < argc && writer.stop == 0) {
        const char *arg = shave_echo_arg(argv, index);
        size_t length;

        if (first_operand == 0) {
            shave_echo_write_byte(&writer, ' ');
        }
        first_operand = 0;

        if (interpret != 0) {
            shave_echo_write_interpreted(&writer, arg);
        } else {
            length = 0;
            while (arg[length] != '\0') {
                length++;
            }
            shave_echo_write_bytes(&writer, arg, length);
        }
        index++;
    }

    if (suppress_newline == 0 && writer.stop == 0) {
        shave_echo_write_byte(&writer, '\n');
    }

    if (fflush(out) != 0) {
        writer.err = 1;
    }
    if (ferror(out) != 0) {
        writer.err = 1;
    }
    return writer.err != 0 ? 1 : 0;
}

int shave_echo_builtin_fp(FILE *out, int argc, char *const argv[])
{
    return shave_echo_emit(out, argc, argv, 0);
}

int shave_echo_builtin(int argc, char *const argv[])
{
    return shave_echo_emit(stdout, argc, argv, 0);
}

int shave_echo_builtin_xpg_fp(FILE *out, int argc, char *const argv[])
{
    return shave_echo_emit(out, argc, argv, 1);
}

int shave_echo_builtin_xpg(int argc, char *const argv[])
{
    return shave_echo_emit(stdout, argc, argv, 1);
}
