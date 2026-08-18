/*
 * shave_wc.c - In-process GNU wc
 *
 * CHANGELOG
 * 1.0.3 - 2026-08-18 - Initial GNU wc-compatible library
 * 1.0.4 - 2026-08-18 - Const-qualify internal argv helper
 */

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
#ifndef _XOPEN_SOURCE
#define _XOPEN_SOURCE 700
#endif

#include "shave_wc.h"

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <wchar.h>
#include <wctype.h>

#define SHAVE_WC_BUF 65536
#define SHAVE_WC_TOTAL_AUTO 0
#define SHAVE_WC_TOTAL_ALWAYS 1
#define SHAVE_WC_TOTAL_ONLY 2
#define SHAVE_WC_TOTAL_NEVER 3

struct shave_wc_writer {
    FILE *out;
    FILE *err;
    int err_flag;
    int status;
};

struct shave_wc_opts {
    int print_lines;
    int print_words;
    int print_chars;
    int print_bytes;
    int print_linelength;
    int total_mode;
    const char *files0_from;
};

struct shave_wc_counts {
    unsigned long long lines;
    unsigned long long words;
    unsigned long long chars;
    unsigned long long bytes;
    long long linelength;
};

static int shave_wc_is_nbspace(wint_t wc)
{
    return wc == 0x00A0 || wc == 0x2007 || wc == 0x202F || wc == 0x2060;
}

static void shave_wc_write(struct shave_wc_writer *writer, const void *data, size_t length)
{
    if (writer->err_flag != 0 || length == 0 || writer->out == NULL) {
        return;
    }
    if (fwrite(data, 1, length, writer->out) != length) {
        writer->err_flag = 1;
        writer->status = 1;
    }
}

static void shave_wc_puts(struct shave_wc_writer *writer, const char *text)
{
    if (text == NULL) {
        return;
    }
    shave_wc_write(writer, text, strlen(text));
}

static void shave_wc_putc(struct shave_wc_writer *writer, char value)
{
    shave_wc_write(writer, &value, 1);
}

static void shave_wc_error(struct shave_wc_writer *writer, const char *path, int errnum)
{
    writer->status = 1;
    if (writer->err == NULL) {
        return;
    }
    if (path != NULL && errnum != 0) {
        (void)fprintf(writer->err, "wc: %s: %s\n", path, strerror(errnum));
    } else if (path != NULL) {
        (void)fprintf(writer->err, "wc: %s\n", path);
    } else if (errnum != 0) {
        (void)fprintf(writer->err, "wc: %s\n", strerror(errnum));
    }
    (void)fflush(writer->err);
}

static void shave_wc_usage_try(struct shave_wc_writer *writer)
{
    if (writer->err == NULL) {
        return;
    }
    (void)fputs("Try 'wc --help' for more information.\n", writer->err);
    (void)fflush(writer->err);
}

static int shave_wc_print_count_n(const struct shave_wc_opts *opts)
{
    return opts->print_lines + opts->print_words + opts->print_chars +
           opts->print_bytes + opts->print_linelength;
}

static void shave_wc_write_uint(struct shave_wc_writer *writer, unsigned long long value,
                                int width, int *need_space)
{
    char buf[32];
    int len;
    int pad;

    len = snprintf(buf, sizeof(buf), "%llu", value);
    if (len < 0) {
        writer->status = 1;
        return;
    }
    if (*need_space != 0) {
        shave_wc_putc(writer, ' ');
    }
    pad = width - len;
    while (pad > 0) {
        shave_wc_putc(writer, ' ');
        pad--;
    }
    shave_wc_puts(writer, buf);
    *need_space = 1;
}

static void shave_wc_write_counts(struct shave_wc_writer *writer, const struct shave_wc_opts *opts,
                                  const struct shave_wc_counts *counts, const char *file, int width)
{
    int need_space = 0;

    if (opts->print_lines != 0) {
        shave_wc_write_uint(writer, counts->lines, width, &need_space);
    }
    if (opts->print_words != 0) {
        shave_wc_write_uint(writer, counts->words, width, &need_space);
    }
    if (opts->print_chars != 0) {
        shave_wc_write_uint(writer, counts->chars, width, &need_space);
    }
    if (opts->print_bytes != 0) {
        shave_wc_write_uint(writer, counts->bytes, width, &need_space);
    }
    if (opts->print_linelength != 0) {
        unsigned long long length = 0;
        if (counts->linelength > 0) {
            length = (unsigned long long)counts->linelength;
        }
        shave_wc_write_uint(writer, length, width, &need_space);
    }
    if (file != NULL) {
        shave_wc_putc(writer, ' ');
        shave_wc_puts(writer, file);
    }
    shave_wc_putc(writer, '\n');
}

static int shave_wc_is_space_byte(unsigned char c, int posixly)
{
    if (isspace((int)c) != 0) {
        return 1;
    }
    if (posixly == 0 && c == 0xA0U) {
        return 1;
    }
    return 0;
}

static void shave_wc_count_buffer(const unsigned char *data, size_t length, struct shave_wc_counts *counts,
                                  int *in_word, long long *linepos, mbstate_t *state, int count_chars,
                                  int count_words, int count_linelength, int posixly)
{
    size_t i = 0;

    counts->bytes += (unsigned long long)length;
    if (count_chars == 0 && count_words == 0 && count_linelength == 0) {
        while (i < length) {
            if (data[i] == '\n') {
                counts->lines++;
            }
            i++;
        }
        return;
    }

    if (MB_CUR_MAX <= 1) {
        while (i < length) {
            unsigned char c = data[i++];
            if (c == '\n') {
                counts->lines++;
                if (*linepos > counts->linelength) {
                    counts->linelength = *linepos;
                }
                *linepos = 0;
                *in_word = 0;
            } else if (c == '\r' || c == '\f') {
                if (*linepos > counts->linelength) {
                    counts->linelength = *linepos;
                }
                *linepos = 0;
                *in_word = 0;
            } else if (c == '\t') {
                *linepos += 8 - (*linepos % 8);
                *in_word = 0;
            } else if (c == ' ') {
                (*linepos)++;
                *in_word = 0;
            } else if (c == '\v') {
                *in_word = 0;
            } else {
                if (count_linelength != 0 && isprint((int)c) != 0) {
                    (*linepos)++;
                }
                if (count_words != 0) {
                    int word2 = !shave_wc_is_space_byte(c, posixly);
                    if (*in_word == 0 && word2 != 0) {
                        counts->words++;
                    }
                    *in_word = word2;
                }
            }
            if (count_chars != 0) {
                counts->chars++;
            }
        }
        return;
    }

    while (i < length) {
        wchar_t wide = 0;
        size_t n;
        int single_byte;

        if (data[i] < 0x80U) {
            n = 1;
            wide = (wchar_t)data[i];
            single_byte = 1;
            memset(state, 0, sizeof(*state));
        } else {
            n = mbrtowc(&wide, (const char *)(data + i), length - i, state);
            single_byte = 0;
            if (n == (size_t)-2) {
                break;
            }
            if (n == (size_t)-1) {
                memset(state, 0, sizeof(*state));
                i++;
                if (count_words != 0 && *in_word == 0) {
                    counts->words++;
                }
                *in_word = 1;
                continue;
            }
            if (n == 0) {
                n = 1;
            }
        }

        switch (wide) {
        case L'\n':
            counts->lines++;
            /* fall through */
        case L'\r':
        case L'\f':
            if (*linepos > counts->linelength) {
                counts->linelength = *linepos;
            }
            *linepos = 0;
            *in_word = 0;
            break;
        case L'\t':
            *linepos += 8 - (*linepos % 8);
            *in_word = 0;
            break;
        case L' ':
            (*linepos)++;
            /* fall through */
        case L'\v':
            *in_word = 0;
            break;
        default:
            if (count_linelength != 0) {
                if (single_byte != 0) {
                    if (isprint((int)wide) != 0) {
                        (*linepos)++;
                    }
                } else {
                    int width = wcwidth(wide);
                    if (width > 0) {
                        *linepos += width;
                    }
                }
            }
            if (count_words != 0) {
                int word2;
                if (single_byte != 0) {
                    word2 = !shave_wc_is_space_byte((unsigned char)wide, posixly);
                } else {
                    word2 = iswspace((wint_t)wide) == 0;
                    if (posixly == 0 && shave_wc_is_nbspace((wint_t)wide) != 0) {
                        word2 = 0;
                    }
                }
                if (*in_word == 0 && word2 != 0) {
                    counts->words++;
                }
                *in_word = word2;
            }
            break;
        }
        if (count_chars != 0) {
            counts->chars++;
        }
        i += n;
    }
}

static int shave_wc_count_fd(int fd, struct shave_wc_counts *counts, const struct shave_wc_opts *opts,
                             int posixly)
{
    unsigned char buf[SHAVE_WC_BUF];
    ssize_t got;
    int in_word = 0;
    long long linepos = 0;
    mbstate_t state;
    int count_chars;
    int count_words = opts->print_words;
    int count_linelength = opts->print_linelength;

    memset(&state, 0, sizeof(state));
    if (MB_CUR_MAX > 1) {
        count_chars = opts->print_chars;
    } else {
        count_chars = 0;
    }

    while ((got = read(fd, buf, sizeof(buf))) > 0) {
        shave_wc_count_buffer(buf, (size_t)got, counts, &in_word, &linepos, &state,
                              count_chars, count_words, count_linelength, posixly);
    }
    if (linepos > counts->linelength) {
        counts->linelength = linepos;
    }
    if (opts->print_chars != 0 && count_chars == 0) {
        counts->chars = counts->bytes;
    }
    if (got < 0) {
        return errno;
    }
    return 0;
}

static int shave_wc_count_file(const char *file, struct shave_wc_counts *counts,
                               const struct shave_wc_opts *opts, struct shave_wc_writer *writer,
                               int posixly)
{
    int fd;
    int read_err;
    int close_err = 0;

    memset(counts, 0, sizeof(*counts));
    if (file == NULL || strcmp(file, "-") == 0) {
        read_err = shave_wc_count_fd(STDIN_FILENO, counts, opts, posixly);
        if (read_err != 0) {
            shave_wc_error(writer, file != NULL ? file : "standard input", read_err);
            return 1;
        }
        return 0;
    }

    fd = open(file, O_RDONLY);
    if (fd < 0) {
        shave_wc_error(writer, file, errno);
        return 1;
    }
    read_err = shave_wc_count_fd(fd, counts, opts, posixly);
    if (close(fd) != 0) {
        close_err = errno;
    }
    if (read_err != 0) {
        shave_wc_error(writer, file, read_err);
        return 1;
    }
    if (close_err != 0) {
        shave_wc_error(writer, file, close_err);
        return 1;
    }
    return 0;
}

static int shave_wc_digits(unsigned long long value)
{
    int width = 1;
    while (value >= 10ULL) {
        value /= 10ULL;
        width++;
    }
    return width;
}

static int shave_wc_number_width(int nfiles, char *const *const files, const struct shave_wc_opts *opts)
{
    int i;
    int width = 1;
    int minimum_width = 1;
    unsigned long long regular_total = 0;
    struct stat st;

    if (opts->total_mode == SHAVE_WC_TOTAL_ONLY) {
        return 1;
    }
    if (nfiles == 0 || (nfiles == 1 && shave_wc_print_count_n(opts) == 1)) {
        return 1;
    }

    for (i = 0; i < nfiles; i++) {
        int rc;
        if (files[i] == NULL || strcmp(files[i], "-") == 0) {
            rc = fstat(STDIN_FILENO, &st);
        } else {
            rc = stat(files[i], &st);
        }
        if (rc != 0) {
            continue;
        }
        if (!S_ISREG(st.st_mode)) {
            minimum_width = 7;
        } else {
            regular_total += (unsigned long long)st.st_size;
        }
    }
    width = shave_wc_digits(regular_total);
    if (width < minimum_width) {
        width = minimum_width;
    }
    return width;
}

static int shave_wc_parse_total(const char *value)
{
    if (value == NULL) {
        return -1;
    }
    if (strcmp(value, "auto") == 0) {
        return SHAVE_WC_TOTAL_AUTO;
    }
    if (strcmp(value, "always") == 0) {
        return SHAVE_WC_TOTAL_ALWAYS;
    }
    if (strcmp(value, "only") == 0) {
        return SHAVE_WC_TOTAL_ONLY;
    }
    if (strcmp(value, "never") == 0) {
        return SHAVE_WC_TOTAL_NEVER;
    }
    return -1;
}

static int shave_wc_long_eq(const char *arg, const char *name, const char **value)
{
    size_t nlen = strlen(name);
    if (strncmp(arg, name, nlen) != 0) {
        return 0;
    }
    if (arg[nlen] == '\0') {
        *value = NULL;
        return 1;
    }
    if (arg[nlen] == '=') {
        *value = arg + nlen + 1;
        return 1;
    }
    return 0;
}

static int shave_wc_parse_args(int argc, char *const *const argv, struct shave_wc_opts *opts,
                               int *file_index, struct shave_wc_writer *writer)
{
    int i = 1;

    opts->print_lines = 0;
    opts->print_words = 0;
    opts->print_chars = 0;
    opts->print_bytes = 0;
    opts->print_linelength = 0;
    opts->total_mode = SHAVE_WC_TOTAL_AUTO;
    opts->files0_from = NULL;

    while (i < argc) {
        const char *arg = argv[i];
        const char *value = NULL;
        if (arg == NULL) {
            writer->status = 1;
            return 1;
        }
        if (strcmp(arg, "--") == 0) {
            i++;
            break;
        }
        if (arg[0] != '-' || arg[1] == '\0') {
            break;
        }
        if (arg[1] == '-') {
            if (shave_wc_long_eq(arg, "--bytes", &value)) {
                opts->print_bytes = 1;
            } else if (shave_wc_long_eq(arg, "--chars", &value)) {
                opts->print_chars = 1;
            } else if (shave_wc_long_eq(arg, "--lines", &value)) {
                opts->print_lines = 1;
            } else if (shave_wc_long_eq(arg, "--words", &value)) {
                opts->print_words = 1;
            } else if (shave_wc_long_eq(arg, "--max-line-length", &value)) {
                opts->print_linelength = 1;
            } else if (shave_wc_long_eq(arg, "--files0-from", &value)) {
                if (value == NULL) {
                    i++;
                    if (i >= argc) {
                        if (writer->err != NULL) {
                            (void)fputs("wc: option '--files0-from' requires an argument\n", writer->err);
                            shave_wc_usage_try(writer);
                        }
                        writer->status = 1;
                        return 1;
                    }
                    value = argv[i];
                }
                opts->files0_from = value;
            } else if (shave_wc_long_eq(arg, "--total", &value)) {
                int mode;
                if (value == NULL) {
                    i++;
                    if (i >= argc) {
                        if (writer->err != NULL) {
                            (void)fputs("wc: option '--total' requires an argument\n", writer->err);
                            shave_wc_usage_try(writer);
                        }
                        writer->status = 1;
                        return 1;
                    }
                    value = argv[i];
                }
                mode = shave_wc_parse_total(value);
                if (mode < 0) {
                    if (writer->err != NULL) {
                        (void)fprintf(writer->err, "wc: invalid argument '%s' for '--total'\n", value);
                        shave_wc_usage_try(writer);
                    }
                    writer->status = 1;
                    return 1;
                }
                opts->total_mode = mode;
            } else if (strcmp(arg, "--help") == 0) {
                if (writer->out != NULL) {
                    (void)fputs("Usage: wc [OPTION]... [FILE]...\n", writer->out);
                    (void)fflush(writer->out);
                }
                *file_index = argc;
                return 2;
            } else if (strcmp(arg, "--version") == 0) {
                if (writer->out != NULL) {
                    (void)fputs("shave_wc 1.0.3\n", writer->out);
                    (void)fflush(writer->out);
                }
                *file_index = argc;
                return 2;
            } else {
                if (writer->err != NULL) {
                    (void)fprintf(writer->err, "wc: unrecognized option '%s'\n", arg);
                    shave_wc_usage_try(writer);
                }
                writer->status = 1;
                return 1;
            }
            i++;
            continue;
        }
        {
            const char *cursor = arg + 1;
            while (*cursor != '\0') {
                switch (*cursor) {
                case 'c':
                    opts->print_bytes = 1;
                    break;
                case 'm':
                    opts->print_chars = 1;
                    break;
                case 'l':
                    opts->print_lines = 1;
                    break;
                case 'w':
                    opts->print_words = 1;
                    break;
                case 'L':
                    opts->print_linelength = 1;
                    break;
                default:
                    if (writer->err != NULL) {
                        (void)fprintf(writer->err, "wc: invalid option -- '%c'\n", *cursor);
                        shave_wc_usage_try(writer);
                    }
                    writer->status = 1;
                    return 1;
                }
                cursor++;
            }
        }
        i++;
    }

    if (shave_wc_print_count_n(opts) == 0) {
        opts->print_lines = 1;
        opts->print_words = 1;
        opts->print_bytes = 1;
    }
    *file_index = i;
    return 0;
}

static int shave_wc_read_files0(const char *path, char ***out_files, int *out_n, struct shave_wc_writer *writer)
{
    FILE *in;
    char *buf = NULL;
    size_t used = 0;
    size_t cap = 0;
    int n = 0;
    int i;
    int close_stdin = 0;
    int c;

    if (path != NULL && strcmp(path, "-") == 0) {
        in = stdin;
    } else {
        in = fopen(path, "r");
        if (in == NULL) {
            if (writer->err != NULL) {
                (void)fprintf(writer->err, "wc: cannot open '%s' for reading: %s\n", path, strerror(errno));
                (void)fflush(writer->err);
            }
            writer->status = 1;
            return 1;
        }
        close_stdin = 1;
    }

    while ((c = fgetc(in)) != EOF) {
        if (used + 1 >= cap) {
            size_t next = cap == 0 ? 256 : cap * 2;
            char *grown = realloc(buf, next);
            if (grown == NULL) {
                free(buf);
                if (close_stdin != 0) {
                    (void)fclose(in);
                }
                writer->status = 1;
                return 1;
            }
            buf = grown;
            cap = next;
        }
        buf[used++] = (char)c;
    }
    if (ferror(in) != 0) {
        free(buf);
        if (close_stdin != 0) {
            (void)fclose(in);
        }
        shave_wc_error(writer, path, errno != 0 ? errno : EIO);
        return 1;
    }
    if (close_stdin != 0) {
        (void)fclose(in);
    }
    if (used == 0) {
        *out_files = NULL;
        *out_n = 0;
        return 0;
    }
    if (buf[used - 1] != '\0') {
        if (used + 1 >= cap) {
            char *grown = realloc(buf, used + 1);
            if (grown == NULL) {
                free(buf);
                writer->status = 1;
                return 1;
            }
            buf = grown;
        }
        buf[used++] = '\0';
    }
    for (i = 0; i < (int)used; i++) {
        if (buf[i] == '\0') {
            n++;
        }
    }
    *out_files = malloc((size_t)n * sizeof(char *));
    if (*out_files == NULL) {
        free(buf);
        writer->status = 1;
        return 1;
    }
    n = 0;
    (*out_files)[0] = buf;
    for (i = 0; i < (int)used; i++) {
        if (buf[i] == '\0') {
            if (i + 1 < (int)used) {
                n++;
                (*out_files)[n] = buf + i + 1;
            }
        }
    }
    *out_n = n + 1;
    return 0;
}

static int shave_wc_emit(FILE *out, FILE *err, int argc, char *const argv[])
{
    struct shave_wc_writer writer;
    struct shave_wc_opts opts;
    struct shave_wc_counts total;
    struct shave_wc_counts one;
    char **files = NULL;
    char **owned_files = NULL;
    int file_index = 1;
    int nfiles = 0;
    int width;
    int i;
    int posixly;
    int parse;
    int processed = 0;

    writer.out = out;
    writer.err = err;
    writer.err_flag = 0;
    writer.status = 0;

    if (out == NULL) {
        return 1;
    }
    if (argc > 0 && argv == NULL) {
        return 1;
    }

    parse = shave_wc_parse_args(argc, argv, &opts, &file_index, &writer);
    if (parse == 2) {
        return 0;
    }
    if (parse != 0) {
        return 1;
    }

    posixly = getenv("POSIXLY_CORRECT") != NULL ? 1 : 0;
    memset(&total, 0, sizeof(total));

    if (opts.files0_from != NULL) {
        if (file_index < argc) {
            if (err != NULL) {
                (void)fprintf(err, "wc: extra operand '%s'\n", argv[file_index]);
                (void)fputs("file operands cannot be combined with --files0-from\n", err);
                shave_wc_usage_try(&writer);
            }
            return 1;
        }
        if (shave_wc_read_files0(opts.files0_from, &owned_files, &nfiles, &writer) != 0) {
            return 1;
        }
        files = owned_files;
    } else if (file_index < argc) {
        files = (char **)(argv + file_index);
        nfiles = argc - file_index;
    } else {
        static char *stdin_only[] = { NULL };
        files = stdin_only;
        nfiles = 1;
    }

    width = shave_wc_number_width(nfiles, files, &opts);

    for (i = 0; i < nfiles; i++) {
        const char *file = files[i];
        int failed;

        if (file != NULL && file[0] == '\0') {
            if (err != NULL) {
                (void)fputs("wc: invalid zero-length file name\n", err);
                (void)fflush(err);
            }
            writer.status = 1;
            continue;
        }
        if (opts.files0_from != NULL && strcmp(opts.files0_from, "-") == 0 &&
            file != NULL && strcmp(file, "-") == 0) {
            if (err != NULL) {
                (void)fputs("wc: when reading file names from stdin, no file name of '-' allowed\n", err);
                (void)fflush(err);
            }
            writer.status = 1;
            continue;
        }

        failed = shave_wc_count_file(file, &one, &opts, &writer, posixly);
        if (failed == 0) {
            if (opts.total_mode != SHAVE_WC_TOTAL_ONLY) {
                shave_wc_write_counts(&writer, &opts, &one, file, width);
            }
            total.lines += one.lines;
            total.words += one.words;
            total.chars += one.chars;
            total.bytes += one.bytes;
            if (one.linelength > total.linelength) {
                total.linelength = one.linelength;
            }
        }
        processed++;
    }

    if (opts.total_mode != SHAVE_WC_TOTAL_NEVER &&
        (opts.total_mode != SHAVE_WC_TOTAL_AUTO || processed > 1)) {
        shave_wc_write_counts(&writer, &opts, &total,
                              opts.total_mode != SHAVE_WC_TOTAL_ONLY ? "total" : NULL, width);
    }

    if (owned_files != NULL) {
        if (nfiles > 0) {
            free(owned_files[0]);
        }
        free(owned_files);
    }
    if (writer.out != NULL && fflush(writer.out) != 0) {
        writer.err_flag = 1;
        writer.status = 1;
    }
    if (writer.out != NULL && ferror(writer.out) != 0) {
        writer.status = 1;
    }
    return writer.status != 0 ? 1 : 0;
}

int shave_wc_fp(FILE *out, FILE *err, int argc, char *const argv[])
{
    return shave_wc_emit(out, err, argc, argv);
}

int shave_wc(int argc, char *const argv[])
{
    return shave_wc_emit(stdout, stderr, argc, argv);
}
