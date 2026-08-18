/*
 * shave_printf_builtin.c - In-process Bash builtin printf
 *
 * CHANGELOG
 * 1.0.2 - 2026-08-18 - Const-qualify option-scan argv helper
 * 1.0.1 - 2026-08-18 - Missing numeric args are zero, not an error
 * 1.0.0 - 2026-08-18 - Initial Bash-compatible printf builtin library
 */

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include "shave_printf_builtin.h"

#include <errno.h>
#include <limits.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define SHAVE_PRINTF_NUMBUF 512
#define SHAVE_PRINTF_TIMEBUF 256

struct shave_printf_writer {
    FILE *out;
    int err;
    int status;
    int stop;
    int counting;
    size_t count;
};

struct shave_printf_conv {
    int flag_minus;
    int flag_plus;
    int flag_space;
    int flag_hash;
    int flag_zero;
    int flag_quote;
    int width;
    int prec;
    int has_width;
    int has_prec;
    unsigned char spec;
    char timefmt[SHAVE_PRINTF_TIMEBUF];
};

static int shave_printf_is_hex(unsigned char c)
{
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

static unsigned int shave_printf_hex_val(unsigned char c)
{
    if (c >= '0' && c <= '9') {
        return (unsigned int)(c - '0');
    }
    if (c >= 'a' && c <= 'f') {
        return (unsigned int)(c - 'a' + 10);
    }
    return (unsigned int)(c - 'A' + 10);
}

static const char *shave_printf_arg(char *const *const argv, int argc, int index)
{
    if (argv == NULL || index < 0 || index >= argc || argv[index] == NULL) {
        return "";
    }
    return argv[index];
}

static void shave_printf_write_bytes(struct shave_printf_writer *writer, const void *data, size_t length)
{
    if (writer->err != 0 || writer->stop != 0 || length == 0) {
        return;
    }
    if (writer->counting != 0) {
        writer->count += length;
        return;
    }
    if (fwrite(data, 1, length, writer->out) != length) {
        writer->err = 1;
    }
}

static void shave_printf_write_byte(struct shave_printf_writer *writer, unsigned char value)
{
    shave_printf_write_bytes(writer, &value, 1);
}

static void shave_printf_write_utf8(struct shave_printf_writer *writer, unsigned long codepoint)
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
    shave_printf_write_bytes(writer, buf, (size_t)count);
}

static int shave_printf_safe_unquoted(unsigned char c)
{
    if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) {
        return 1;
    }
    if (c == '_' || c == '/' || c == '.' || c == '+' || c == ':' || c == '=' || c == '%' || c == '@' || c == '-') {
        return 1;
    }
    if (c >= 0x80U) {
        return 1;
    }
    return 0;
}

static int shave_printf_needs_dollar_quote(const char *text, size_t length)
{
    size_t i;

    for (i = 0; i < length; i++) {
        unsigned char c = (unsigned char)text[i];
        if (c < 0x20U || c == 0x7FU) {
            return 1;
        }
    }
    return 0;
}

static void shave_printf_write_quoted_dollar(struct shave_printf_writer *writer, const char *text, size_t length, int remaining)
{
    size_t i;

    shave_printf_write_byte(writer, '$');
    if (remaining >= 0) {
        remaining--;
        if (remaining == 0) {
            return;
        }
    }
    shave_printf_write_byte(writer, '\'');
    if (remaining >= 0) {
        remaining--;
        if (remaining == 0) {
            return;
        }
    }
    for (i = 0; i < length; i++) {
        unsigned char c = (unsigned char)text[i];
        const char *esc = NULL;
        char oct[5];

        switch (c) {
        case '\a':
            esc = "\\a";
            break;
        case '\b':
            esc = "\\b";
            break;
        case '\033':
            esc = "\\E";
            break;
        case '\f':
            esc = "\\f";
            break;
        case '\n':
            esc = "\\n";
            break;
        case '\r':
            esc = "\\r";
            break;
        case '\t':
            esc = "\\t";
            break;
        case '\v':
            esc = "\\v";
            break;
        case '\\':
            esc = "\\\\";
            break;
        case '\'':
            esc = "\\'";
            break;
        default:
            break;
        }
        if (esc != NULL) {
            size_t n = 2;
            if (remaining >= 0 && remaining < (int)n) {
                n = (size_t)remaining;
            }
            shave_printf_write_bytes(writer, esc, n);
            if (remaining >= 0) {
                remaining -= (int)n;
                if (remaining <= 0) {
                    return;
                }
            }
            continue;
        }
        if (c < 0x20U || c == 0x7FU) {
            oct[0] = '\\';
            oct[1] = (char)('0' + ((c >> 6) & 0x7U));
            oct[2] = (char)('0' + ((c >> 3) & 0x7U));
            oct[3] = (char)('0' + (c & 0x7U));
            oct[4] = '\0';
            {
                size_t n = 4;
                if (remaining >= 0 && remaining < (int)n) {
                    n = (size_t)remaining;
                }
                shave_printf_write_bytes(writer, oct, n);
                if (remaining >= 0) {
                    remaining -= (int)n;
                    if (remaining <= 0) {
                        return;
                    }
                }
            }
            continue;
        }
        shave_printf_write_byte(writer, c);
        if (remaining >= 0) {
            remaining--;
            if (remaining <= 0) {
                return;
            }
        }
    }
    shave_printf_write_byte(writer, '\'');
}

static void shave_printf_write_quoted_backslash(struct shave_printf_writer *writer, const char *text, size_t length, int remaining)
{
    size_t i;

    for (i = 0; i < length; i++) {
        unsigned char c = (unsigned char)text[i];
        if (shave_printf_safe_unquoted(c) == 0) {
            shave_printf_write_byte(writer, '\\');
            if (remaining >= 0) {
                remaining--;
                if (remaining <= 0) {
                    return;
                }
            }
        }
        shave_printf_write_byte(writer, c);
        if (remaining >= 0) {
            remaining--;
            if (remaining <= 0) {
                return;
            }
        }
    }
}

static void shave_printf_write_quoted(struct shave_printf_writer *writer, const char *text, int prec, int quote_after_prec)
{
    size_t length = 0;
    int remaining = -1;

    while (text[length] != '\0') {
        length++;
    }
    if (quote_after_prec != 0 && prec >= 0 && (size_t)prec < length) {
        length = (size_t)prec;
    }
    if (quote_after_prec == 0 && prec >= 0) {
        remaining = prec;
    }
    if (length == 0) {
        if (remaining == 0) {
            return;
        }
        shave_printf_write_byte(writer, '\'');
        if (remaining == 1) {
            return;
        }
        shave_printf_write_byte(writer, '\'');
        return;
    }
    if (shave_printf_needs_dollar_quote(text, length) != 0) {
        shave_printf_write_quoted_dollar(writer, text, length, remaining);
        return;
    }
    {
        size_t i;
        int unsafe = 0;
        for (i = 0; i < length; i++) {
            if (shave_printf_safe_unquoted((unsigned char)text[i]) == 0) {
                unsafe = 1;
                break;
            }
        }
        if (unsafe == 0) {
            size_t n = length;
            if (remaining >= 0 && (size_t)remaining < n) {
                n = (size_t)remaining;
            }
            shave_printf_write_bytes(writer, text, n);
            return;
        }
    }
    shave_printf_write_quoted_backslash(writer, text, length, remaining);
}

static const char *shave_printf_consume_escape(struct shave_printf_writer *writer, const char *text, int percent_b)
{
    const unsigned char *cursor;
    unsigned char next;
    unsigned int value;
    unsigned long codepoint;
    int digits;
    int max_digits;
    unsigned char kind;

    cursor = (const unsigned char *)text;
    if (*cursor != '\\') {
        return text;
    }
    cursor++;
    if (*cursor == '\0') {
        shave_printf_write_byte(writer, '\\');
        return (const char *)cursor;
    }
    next = *cursor;
    switch (next) {
    case 'a':
        shave_printf_write_byte(writer, '\a');
        cursor++;
        break;
    case 'b':
        shave_printf_write_byte(writer, '\b');
        cursor++;
        break;
    case 'c':
        if (percent_b != 0) {
            writer->stop = 1;
        } else {
            shave_printf_write_byte(writer, '\\');
            shave_printf_write_byte(writer, 'c');
        }
        cursor++;
        break;
    case 'e':
    case 'E':
        shave_printf_write_byte(writer, 0x1BU);
        cursor++;
        break;
    case 'f':
        shave_printf_write_byte(writer, '\f');
        cursor++;
        break;
    case 'n':
        shave_printf_write_byte(writer, '\n');
        cursor++;
        break;
    case 'r':
        shave_printf_write_byte(writer, '\r');
        cursor++;
        break;
    case 't':
        shave_printf_write_byte(writer, '\t');
        cursor++;
        break;
    case 'v':
        shave_printf_write_byte(writer, '\v');
        cursor++;
        break;
    case '\\':
        shave_printf_write_byte(writer, '\\');
        cursor++;
        break;
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
        value = 0;
        digits = 0;
        max_digits = 3;
        if (percent_b != 0 && next == '0') {
            max_digits = 4;
        }
        while (digits < max_digits && *cursor >= '0' && *cursor <= '7') {
            value = (value << 3) | (unsigned int)(*cursor - '0');
            cursor++;
            digits++;
        }
        shave_printf_write_byte(writer, (unsigned char)value);
        break;
    case 'x':
        cursor++;
        if (!shave_printf_is_hex(*cursor)) {
            shave_printf_write_byte(writer, '\\');
            shave_printf_write_byte(writer, 'x');
            break;
        }
        value = shave_printf_hex_val(*cursor);
        cursor++;
        if (shave_printf_is_hex(*cursor)) {
            value = (value << 4) | shave_printf_hex_val(*cursor);
            cursor++;
        }
        shave_printf_write_byte(writer, (unsigned char)value);
        break;
    case 'u':
    case 'U':
        kind = next;
        max_digits = (kind == 'u') ? 4 : 8;
        cursor++;
        if (!shave_printf_is_hex(*cursor)) {
            shave_printf_write_byte(writer, '\\');
            shave_printf_write_byte(writer, kind);
            break;
        }
        codepoint = 0;
        digits = 0;
        while (digits < max_digits && shave_printf_is_hex(*cursor)) {
            codepoint = (codepoint << 4) | shave_printf_hex_val(*cursor);
            cursor++;
            digits++;
        }
        shave_printf_write_utf8(writer, codepoint);
        break;
    default:
        shave_printf_write_byte(writer, '\\');
        shave_printf_write_byte(writer, next);
        cursor++;
        break;
    }
    return (const char *)cursor;
}

static void shave_printf_write_interpreted(struct shave_printf_writer *writer, const char *text, int percent_b)
{
    const char *cursor;

    cursor = text;
    while (*cursor != '\0' && writer->stop == 0) {
        if (*cursor != '\\') {
            shave_printf_write_byte(writer, (unsigned char)*cursor);
            cursor++;
            continue;
        }
        cursor = shave_printf_consume_escape(writer, cursor, percent_b);
    }
}

static int shave_printf_parse_ll(const char *text, long long *value)
{
    char *end = NULL;
    long long parsed;

    if (text == NULL || text[0] == '\0') {
        *value = 0;
        return 1;
    }
    errno = 0;
    parsed = strtoll(text, &end, 0);
    if (end == text) {
        *value = 0;
        return 1;
    }
    *value = parsed;
    if (*end != '\0' || errno == ERANGE) {
        return 1;
    }
    return 0;
}

static int shave_printf_parse_ull(const char *text, unsigned long long *value)
{
    char *end = NULL;
    unsigned long long parsed;

    if (text == NULL || text[0] == '\0') {
        *value = 0;
        return 1;
    }
    errno = 0;
    parsed = strtoull(text, &end, 0);
    if (end == text) {
        *value = 0;
        return 1;
    }
    *value = parsed;
    if (*end != '\0' || errno == ERANGE) {
        return 1;
    }
    return 0;
}

static int shave_printf_parse_ld(const char *text, long double *value)
{
    char *end = NULL;
    long double parsed;

    if (text == NULL || text[0] == '\0') {
        *value = 0.0L;
        return 1;
    }
    errno = 0;
    parsed = strtold(text, &end);
    if (end == text) {
        *value = 0.0L;
        return 1;
    }
    *value = parsed;
    if (*end != '\0' || errno == ERANGE) {
        return 1;
    }
    return 0;
}

static int shave_printf_take_arg(int *index, int argc)
{
    if (*index >= argc) {
        return 0;
    }
    (*index)++;
    return 1;
}

static int shave_printf_parse_star(char *const *const argv, int argc, int *index, int *had_error)
{
    long long value = 0;
    const char *text;

    if (shave_printf_take_arg(index, argc) == 0) {
        return 0;
    }
    text = shave_printf_arg(argv, argc, *index - 1);
    if (shave_printf_parse_ll(text, &value) != 0) {
        *had_error = 1;
    }
    if (value > INT_MAX) {
        return INT_MAX;
    }
    if (value < INT_MIN) {
        return INT_MIN;
    }
    return (int)value;
}

static const char *shave_printf_parse_conv(const char *fmt, struct shave_printf_conv *conv,
                                           char *const *const argv, int argc, int *index, int *had_error)
{
    const char *cursor = fmt;

    memset(conv, 0, sizeof(*conv));
    conv->width = 0;
    conv->prec = -1;
    while (*cursor == '-' || *cursor == '+' || *cursor == ' ' || *cursor == '#' || *cursor == '0' || *cursor == '\'') {
        if (*cursor == '-') {
            conv->flag_minus = 1;
        } else if (*cursor == '+') {
            conv->flag_plus = 1;
        } else if (*cursor == ' ') {
            conv->flag_space = 1;
        } else if (*cursor == '#') {
            conv->flag_hash = 1;
        } else if (*cursor == '0') {
            conv->flag_zero = 1;
        } else {
            conv->flag_quote = 1;
        }
        cursor++;
    }
    if (*cursor == '*') {
        int width;
        cursor++;
        width = shave_printf_parse_star(argv, argc, index, had_error);
        if (width < 0) {
            conv->flag_minus = 1;
            if (width == INT_MIN) {
                conv->width = INT_MAX;
            } else {
                conv->width = -width;
            }
        } else {
            conv->width = width;
        }
        conv->has_width = 1;
    } else if (*cursor >= '0' && *cursor <= '9') {
        int width = 0;
        while (*cursor >= '0' && *cursor <= '9') {
            if (width > (INT_MAX - (*cursor - '0')) / 10) {
                width = INT_MAX;
            } else {
                width = (width * 10) + (*cursor - '0');
            }
            cursor++;
        }
        conv->width = width;
        conv->has_width = 1;
    }
    if (*cursor == '.') {
        cursor++;
        conv->has_prec = 1;
        if (*cursor == '*') {
            cursor++;
            conv->prec = shave_printf_parse_star(argv, argc, index, had_error);
            if (conv->prec < 0) {
                conv->prec = -1;
                conv->has_prec = 0;
            }
        } else {
            int prec = 0;
            if (*cursor < '0' || *cursor > '9') {
                conv->prec = 0;
            } else {
                while (*cursor >= '0' && *cursor <= '9') {
                    if (prec > (INT_MAX - (*cursor - '0')) / 10) {
                        prec = INT_MAX;
                    } else {
                        prec = (prec * 10) + (*cursor - '0');
                    }
                    cursor++;
                }
                conv->prec = prec;
            }
        }
    }
    if (*cursor == 'h' || *cursor == 'l' || *cursor == 'L' || *cursor == 'j' || *cursor == 'z' || *cursor == 't') {
        unsigned char first = (unsigned char)*cursor;
        cursor++;
        if ((first == 'h' && *cursor == 'h') || (first == 'l' && *cursor == 'l')) {
            cursor++;
        }
    }
    if (*cursor == '(') {
        size_t tlen = 0;
        cursor++;
        while (*cursor != '\0' && *cursor != ')') {
            if (tlen + 1 < sizeof(conv->timefmt)) {
                conv->timefmt[tlen] = *cursor;
                tlen++;
            }
            cursor++;
        }
        conv->timefmt[tlen] = '\0';
        if (*cursor != ')') {
            return NULL;
        }
        cursor++;
        if (*cursor != 'T' && *cursor != 't') {
            return NULL;
        }
        conv->spec = 'T';
        cursor++;
        return cursor;
    }
    if (*cursor == '\0') {
        return NULL;
    }
    conv->spec = (unsigned char)*cursor;
    cursor++;
    return cursor;
}

static int shave_printf_is_int_spec(unsigned char spec)
{
    return spec == 'd' || spec == 'i' || spec == 'o' || spec == 'u' || spec == 'x' || spec == 'X';
}

static int shave_printf_is_float_spec(unsigned char spec)
{
    return spec == 'e' || spec == 'E' || spec == 'f' || spec == 'F' || spec == 'g' || spec == 'G' || spec == 'a' || spec == 'A';
}

static int shave_printf_is_valid_spec(unsigned char spec)
{
    if (spec == 's' || spec == 'c' || spec == 'b' || spec == 'q' || spec == 'Q' || spec == 'n' || spec == 'T' || spec == '%') {
        return 1;
    }
    return shave_printf_is_int_spec(spec) || shave_printf_is_float_spec(spec);
}

static void shave_printf_pad(struct shave_printf_writer *writer, int count, unsigned char fill)
{
    int i;
    for (i = 0; i < count; i++) {
        shave_printf_write_byte(writer, fill);
    }
}

static size_t shave_printf_measure(void (*emit)(struct shave_printf_writer *, const void *), struct shave_printf_writer *writer, const void *payload)
{
    int saved_counting = writer->counting;
    size_t saved_count = writer->count;
    int saved_stop = writer->stop;
    size_t measured;

    writer->counting = 1;
    writer->count = 0;
    emit(writer, payload);
    measured = writer->count;
    writer->counting = saved_counting;
    writer->count = saved_count;
    writer->stop = saved_stop;
    return measured;
}

struct shave_printf_text_job {
    const char *text;
    int prec;
    int percent_b;
    int quote;
    int quote_after_prec;
};

static void shave_printf_emit_text_job(struct shave_printf_writer *writer, const void *payload)
{
    const struct shave_printf_text_job *job = (const struct shave_printf_text_job *)payload;

    if (job->quote != 0) {
        shave_printf_write_quoted(writer, job->text, job->prec, job->quote_after_prec);
        return;
    }
    if (job->percent_b != 0) {
        shave_printf_write_interpreted(writer, job->text, 1);
        return;
    }
    {
        size_t length = 0;
        while (job->text[length] != '\0' && (job->prec < 0 || (int)length < job->prec)) {
            length++;
        }
        shave_printf_write_bytes(writer, job->text, length);
    }
}

static void shave_printf_emit_padded(struct shave_printf_writer *writer, const struct shave_printf_conv *conv,
                                     void (*emit)(struct shave_printf_writer *, const void *), const void *payload)
{
    size_t content;
    int pad;

    if (conv->width <= 0) {
        emit(writer, payload);
        return;
    }
    content = shave_printf_measure(emit, writer, payload);
    if (writer->stop != 0) {
        emit(writer, payload);
        return;
    }
    pad = conv->width - (int)content;
    if (pad < 0) {
        pad = 0;
    }
    if (conv->flag_minus != 0) {
        emit(writer, payload);
        shave_printf_pad(writer, pad, ' ');
    } else {
        shave_printf_pad(writer, pad, ' ');
        emit(writer, payload);
    }
}

static int shave_printf_build_num_fmt(char *buf, size_t buflen, const struct shave_printf_conv *conv, const char *length, unsigned char spec)
{
    size_t used = 0;

    if (buflen < 8) {
        return 1;
    }
    buf[used++] = '%';
    if (conv->flag_minus != 0) {
        buf[used++] = '-';
    }
    if (conv->flag_plus != 0) {
        buf[used++] = '+';
    }
    if (conv->flag_space != 0) {
        buf[used++] = ' ';
    }
    if (conv->flag_hash != 0) {
        buf[used++] = '#';
    }
    if (conv->flag_zero != 0) {
        buf[used++] = '0';
    }
    if (conv->flag_quote != 0) {
        buf[used++] = '\'';
    }
    if (conv->has_width != 0) {
        int n = snprintf(buf + used, buflen - used, "%d", conv->width);
        if (n < 0 || (size_t)n >= buflen - used) {
            return 1;
        }
        used += (size_t)n;
    }
    if (conv->has_prec != 0 && conv->prec >= 0) {
        int n = snprintf(buf + used, buflen - used, ".%d", conv->prec);
        if (n < 0 || (size_t)n >= buflen - used) {
            return 1;
        }
        used += (size_t)n;
    }
    while (*length != '\0') {
        if (used + 1 >= buflen) {
            return 1;
        }
        buf[used++] = *length;
        length++;
    }
    if (used + 2 >= buflen) {
        return 1;
    }
    buf[used++] = (char)spec;
    buf[used] = '\0';
    return 0;
}

static void shave_printf_emit_time(struct shave_printf_writer *writer, const struct shave_printf_conv *conv, const char *arg, int *had_error)
{
    time_t when;
    struct tm parts;
    char formatted[SHAVE_PRINTF_TIMEBUF];
    size_t n;
    long long epoch = 0;
    int missing;

    missing = (arg == NULL);
    if (missing == 0 && shave_printf_parse_ll(arg, &epoch) != 0) {
        *had_error = 1;
        epoch = 0;
    }
    if (missing != 0 || epoch == -1) {
        when = time(NULL);
    } else {
        when = (time_t)epoch;
    }
    if (localtime_r(&when, &parts) == NULL) {
        *had_error = 1;
        return;
    }
    n = strftime(formatted, sizeof(formatted), conv->timefmt, &parts);
    shave_printf_write_bytes(writer, formatted, n);
}

static int shave_printf_apply_conv(struct shave_printf_writer *writer, const struct shave_printf_conv *conv,
                                   char *const *const argv, int argc, int *index, int *consumed)
{
    const char *arg;
    int had_error = 0;
    int have_arg = 1;
    char numfmt[64];
    char numbuf[SHAVE_PRINTF_NUMBUF];
    int n;

    if (shave_printf_is_valid_spec(conv->spec) == 0) {
        writer->status = 1;
        writer->stop = 1;
        return 1;
    }
    if (conv->spec == '%') {
        if (conv->flag_minus != 0 || conv->flag_plus != 0 || conv->flag_space != 0 ||
            conv->flag_hash != 0 || conv->flag_zero != 0 || conv->flag_quote != 0 ||
            conv->has_width != 0 || conv->has_prec != 0) {
            writer->status = 1;
            writer->stop = 1;
            return 1;
        }
        shave_printf_write_byte(writer, '%');
        return 0;
    }
    if (conv->spec == 'n') {
        if (shave_printf_take_arg(index, argc) != 0) {
            *consumed = 1;
        }
        return 0;
    }

    if (conv->spec == 'T') {
        arg = NULL;
        if (shave_printf_take_arg(index, argc) != 0) {
            *consumed = 1;
            arg = shave_printf_arg(argv, argc, *index - 1);
        }
        shave_printf_emit_time(writer, conv, arg, &had_error);
        if (had_error != 0) {
            writer->status = 1;
        }
        return had_error;
    }

    arg = "";
    if (shave_printf_take_arg(index, argc) != 0) {
        *consumed = 1;
        arg = shave_printf_arg(argv, argc, *index - 1);
    } else {
        have_arg = 0;
    }

    if (conv->spec == 's' || conv->spec == 'b' || conv->spec == 'q' || conv->spec == 'Q') {
        struct shave_printf_text_job job;
        job.text = arg;
        job.prec = conv->prec;
        job.percent_b = (conv->spec == 'b');
        job.quote = (conv->spec == 'q' || conv->spec == 'Q');
        job.quote_after_prec = (conv->spec == 'Q');
        shave_printf_emit_padded(writer, conv, shave_printf_emit_text_job, &job);
        return 0;
    }

    if (conv->spec == 'c') {
        unsigned char ch = (unsigned char)arg[0];
        if (conv->width > 1 && conv->flag_minus == 0) {
            shave_printf_pad(writer, conv->width - 1, ' ');
        }
        shave_printf_write_byte(writer, ch);
        if (conv->width > 1 && conv->flag_minus != 0) {
            shave_printf_pad(writer, conv->width - 1, ' ');
        }
        return 0;
    }

    if (shave_printf_is_int_spec(conv->spec) != 0) {
        if (conv->spec == 'u' || conv->spec == 'o' || conv->spec == 'x' || conv->spec == 'X') {
            unsigned long long value = 0;
            if (have_arg != 0 && shave_printf_parse_ull(arg, &value) != 0) {
                had_error = 1;
            }
            if (shave_printf_build_num_fmt(numfmt, sizeof(numfmt), conv, "ll", conv->spec) != 0) {
                writer->status = 1;
                return 1;
            }
            n = snprintf(numbuf, sizeof(numbuf), numfmt, value);
        } else {
            long long value = 0;
            if (have_arg != 0 && shave_printf_parse_ll(arg, &value) != 0) {
                had_error = 1;
            }
            if (shave_printf_build_num_fmt(numfmt, sizeof(numfmt), conv, "ll", conv->spec) != 0) {
                writer->status = 1;
                return 1;
            }
            n = snprintf(numbuf, sizeof(numbuf), numfmt, value);
        }
        if (n < 0) {
            writer->status = 1;
            return 1;
        }
        if ((size_t)n >= sizeof(numbuf)) {
            n = (int)sizeof(numbuf) - 1;
        }
        shave_printf_write_bytes(writer, numbuf, (size_t)n);
        if (had_error != 0) {
            writer->status = 1;
        }
        return had_error;
    }

    if (shave_printf_is_float_spec(conv->spec) != 0) {
        long double value = 0.0L;
        if (have_arg != 0 && shave_printf_parse_ld(arg, &value) != 0) {
            had_error = 1;
        }
        if (shave_printf_build_num_fmt(numfmt, sizeof(numfmt), conv, "L", conv->spec) != 0) {
            writer->status = 1;
            return 1;
        }
        n = snprintf(numbuf, sizeof(numbuf), numfmt, value);
        if (n < 0) {
            writer->status = 1;
            return 1;
        }
        if ((size_t)n >= sizeof(numbuf)) {
            n = (int)sizeof(numbuf) - 1;
        }
        shave_printf_write_bytes(writer, numbuf, (size_t)n);
        if (had_error != 0) {
            writer->status = 1;
        }
        return had_error;
    }

    writer->status = 1;
    writer->stop = 1;
    return 1;
}

static int shave_printf_run_format(struct shave_printf_writer *writer, const char *format,
                                   char *const *const argv, int argc, int *index, int *consumed)
{
    const char *cursor = format;

    while (*cursor != '\0' && writer->stop == 0 && writer->err == 0) {
        if (*cursor == '%') {
            struct shave_printf_conv conv;
            const char *next;

            cursor++;
            if (*cursor == '\0') {
                shave_printf_write_byte(writer, '%');
                break;
            }
            next = shave_printf_parse_conv(cursor, &conv, argv, argc, index, &writer->status);
            if (next == NULL) {
                writer->status = 1;
                writer->stop = 1;
                return 1;
            }
            if (shave_printf_apply_conv(writer, &conv, argv, argc, index, consumed) != 0 && writer->stop != 0) {
                return writer->status;
            }
            cursor = next;
            continue;
        }
        if (*cursor == '\\') {
            cursor = shave_printf_consume_escape(writer, cursor, 0);
            continue;
        }
        shave_printf_write_byte(writer, (unsigned char)*cursor);
        cursor++;
    }
    return writer->status;
}

static int shave_printf_skip_options(int argc, char *const *const argv, int *index)
{
    while (*index < argc) {
        const char *arg = argv[*index];
        if (arg == NULL) {
            return 2;
        }
        if (strcmp(arg, "--") == 0) {
            (*index)++;
            return 0;
        }
        if (arg[0] != '-' || arg[1] == '\0') {
            return 0;
        }
        if (arg[1] == 'v') {
            if (arg[2] != '\0') {
                (*index)++;
                continue;
            }
            (*index)++;
            if (*index >= argc) {
                return 2;
            }
            (*index)++;
            continue;
        }
        return 2;
    }
    return 0;
}

static int shave_printf_emit(FILE *out, int argc, char *const argv[])
{
    struct shave_printf_writer writer;
    int index = 1;
    int opt;
    const char *format;
    int saw_conversion;

    if (out == NULL) {
        return 1;
    }
    if (argc > 0 && argv == NULL) {
        return 1;
    }

    writer.out = out;
    writer.err = 0;
    writer.status = 0;
    writer.stop = 0;
    writer.counting = 0;
    writer.count = 0;

    opt = shave_printf_skip_options(argc, argv, &index);
    if (opt != 0) {
        return 2;
    }
    if (index >= argc) {
        return 2;
    }
    format = shave_printf_arg(argv, argc, index);
    index++;

    do {
        int consumed = 0;
        int start = index;
        saw_conversion = 0;
        if (shave_printf_run_format(&writer, format, argv, argc, &index, &consumed) != 0 && writer.stop != 0) {
            break;
        }
        saw_conversion = consumed;
        if (writer.stop != 0) {
            break;
        }
        if (saw_conversion == 0) {
            break;
        }
        if (index == start && index < argc) {
            break;
        }
    } while (index < argc && writer.err == 0 && writer.stop == 0);

    if (writer.counting == 0 && fflush(out) != 0) {
        writer.err = 1;
    }
    if (ferror(out) != 0) {
        writer.err = 1;
    }
    if (writer.err != 0 || writer.status != 0) {
        return 1;
    }
    return 0;
}

int shave_printf_builtin_fp(FILE *out, int argc, char *const argv[])
{
    return shave_printf_emit(out, argc, argv);
}

int shave_printf_builtin(int argc, char *const argv[])
{
    return shave_printf_emit(stdout, argc, argv);
}
