/* vi: set sw=4 ts=4: */
/*
 * Based on busybox code
 *
 * Utility routines.
 *
 * Copyright (C) 2010 Denys Vlasenko
 *
 * Licensed under GPLv2 or later, see file LICENSE in this source tree.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <console.h>
#include <com32.h>

#define ALIGN1
const char bb_hexdigits_upcase[] ALIGN1 = "0123456789ABCDEF";

/* Emit a string of hex representation of bytes */
char* bin2hex(char *p, const char *cp, int count)
{
	while (count) {
		unsigned char c = *cp++;
		/* put lowercase hex digits */
		*p++ = 0x20 | bb_hexdigits_upcase[c >> 4];
		*p++ = 0x20 | bb_hexdigits_upcase[c & 0xf];
		count--;
	}
	return p;
}

//#define rotl32(x,n) (((x) << (n)) | ((x) >> (32 - (n))))
static uint32_t rotl32(uint32_t x, unsigned n)
{
	return (x << n) | (x >> (32 - n));
}

typedef struct md5_ctx_t {
	uint8_t wbuffer[64]; /* always correctly aligned for uint64_t */
	uint64_t total64;    /* must be directly before hash[] */
	uint32_t hash[8];    /* 4 elements for md5, 5 for sha1, 8 for sha256 */
} md5_ctx_t;

static void md5_process_block64(md5_ctx_t *ctx);

/* Feed data through a temporary buffer.
 * The internal buffer remembers previous data until it has 64
 * bytes worth to pass on.
 */
static void common64_hash(md5_ctx_t *ctx, const void *buffer, size_t len)
{
	unsigned bufpos = ctx->total64 & 63;

	ctx->total64 += len;

	while (1) {
		unsigned remaining = 64 - bufpos;
		if (remaining > len)
			remaining = len;
		/* Copy data into aligned buffer */
		memcpy(ctx->wbuffer + bufpos, buffer, remaining);
		len -= remaining;
		buffer = (const char *)buffer + remaining;
		bufpos += remaining;
		/* clever way to do "if (bufpos != 64) break; ... ; bufpos = 0;" */
		bufpos -= 64;
		if (bufpos != 0)
			break;
		/* Buffer is filled up, process it */
		md5_process_block64(ctx);
		/*bufpos = 0; - already is */
	}
}

/* Process the remaining bytes in the buffer */
static void common64_end(md5_ctx_t *ctx)
{
	unsigned bufpos = ctx->total64 & 63;
	/* Pad the buffer to the next 64-byte boundary with 0x80,0,0,0... */
	ctx->wbuffer[bufpos++] = 0x80;

	/* This loop iterates either once or twice, no more, no less */
	while (1) {
		unsigned remaining = 64 - bufpos;
		memset(ctx->wbuffer + bufpos, 0, remaining);
		/* Do we have enough space for the length count? */
		if (remaining >= 8) {
			/* Store the 64-bit counter of bits in the buffer */
			uint64_t t = ctx->total64 << 3;
			/* wbuffer is suitably aligned for this */
			*(uint64_t *) (&ctx->wbuffer[64 - 8]) = t;
		}
		md5_process_block64(ctx);
		if (remaining >= 8)
			break;
		bufpos = 0;
	}
}


/*
 * Compute MD5 checksum of strings according to the
 * definition of MD5 in RFC 1321 from April 1992.
 *
 * Written by Ulrich Drepper <drepper@gnu.ai.mit.edu>, 1995.
 *
 * Copyright (C) 1995-1999 Free Software Foundation, Inc.
 * Copyright (C) 2001 Manuel Novoa III
 * Copyright (C) 2003 Glenn L. McGrath
 * Copyright (C) 2003 Erik Andersen
 *
 * Licensed under GPLv2 or later, see file LICENSE in this source tree.
 */

/* These are the four functions used in the four steps of the MD5 algorithm
 * and defined in the RFC 1321.  The first function is a little bit optimized
 * (as found in Colin Plumbs public domain implementation).
 * #define FF(b, c, d) ((b & c) | (~b & d))
 */
#undef FF
#undef FG
#undef FH
#undef FI
#define FF(b, c, d) (d ^ (b & (c ^ d)))
#define FG(b, c, d) FF(d, b, c)
#define FH(b, c, d) (b ^ c ^ d)
#define FI(b, c, d) (c ^ (b | ~d))

/* Hash a single block, 64 bytes long and 4-byte aligned */
static void md5_process_block64(md5_ctx_t *ctx)
{
	/* Before we start, one word to the strange constants.
	   They are defined in RFC 1321 as
	   T[i] = (int)(4294967296.0 * fabs(sin(i))), i=1..64
	 */
	static const uint32_t C_array[] = {
		/* round 1 */
		0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
		0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
		0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
		0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
		/* round 2 */
		0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
		0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
		0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
		0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
		/* round 3 */
		0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
		0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
		0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x4881d05,
		0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
		/* round 4 */
		0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
		0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
		0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
		0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
	};
	static const char P_array[] ALIGN1 = {
		0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, /* 1 */
		1, 6, 11, 0, 5, 10, 15, 4, 9, 14, 3, 8, 13, 2, 7, 12, /* 2 */
		5, 8, 11, 14, 1, 4, 7, 10, 13, 0, 3, 6, 9, 12, 15, 2, /* 3 */
		0, 7, 14, 5, 12, 3, 10, 1, 8, 15, 6, 13, 4, 11, 2, 9  /* 4 */
	};
	uint32_t *words = (void*) ctx->wbuffer;
	uint32_t A = ctx->hash[0];
	uint32_t B = ctx->hash[1];
	uint32_t C = ctx->hash[2];
	uint32_t D = ctx->hash[3];

	static const char S_array[] ALIGN1 = {
		7, 12, 17, 22,
		5, 9, 14, 20,
		4, 11, 16, 23,
		6, 10, 15, 21
	};
	const uint32_t *pc;
	const char *pp;
	const char *ps;
	int i;
	uint32_t temp;


	pc = C_array;
	pp = P_array;
	ps = S_array - 4;

	for (i = 0; i < 64; i++) {
		if ((i & 0x0f) == 0)
			ps += 4;
		temp = A;
		switch (i >> 4) {
		case 0:
			temp += FF(B, C, D);
			break;
		case 1:
			temp += FG(B, C, D);
			break;
		case 2:
			temp += FH(B, C, D);
			break;
		case 3:
			temp += FI(B, C, D);
		}
		temp += words[(int) (*pp++)] + *pc++;
		temp = rotl32(temp, ps[i & 3]);
		temp += B;
		A = D;
		D = C;
		C = B;
		B = temp;
	}
	/* Add checksum to the starting values */
	ctx->hash[0] += A;
	ctx->hash[1] += B;
	ctx->hash[2] += C;
	ctx->hash[3] += D;

}
#undef FF
#undef FG
#undef FH
#undef FI

/* Initialize structure containing state of computation.
 * (RFC 1321, 3.3: Step 3)
 */
void md5_begin(md5_ctx_t *ctx)
{
	ctx->hash[0] = 0x67452301;
	ctx->hash[1] = 0xefcdab89;
	ctx->hash[2] = 0x98badcfe;
	ctx->hash[3] = 0x10325476;
	ctx->total64 = 0;
}

/* Used also for sha1 and sha256 */
void md5_hash(md5_ctx_t *ctx, const void *buffer, size_t len)
{
	common64_hash(ctx, buffer, len);
}

/* Process the remaining bytes in the buffer and put result from CTX
 * in first 16 bytes following RESBUF.  The result is always in little
 * endian byte order, so that a byte-wise output yields to the wanted
 * ASCII representation of the message digest.
 */
void md5_end(md5_ctx_t *ctx, void *resbuf)
{
	/* MD5 stores total in LE, need to swap on BE arches: */
	common64_end(ctx);

	/* The MD5 result is in little endian byte order */
	memcpy(resbuf, ctx->hash, sizeof(ctx->hash[0]) * 4);
}

/*
 *  Copyright (C) 2003 Glenn L. McGrath
 *  Copyright (C) 2003-2004 Erik Andersen
 *
 * Licensed under GPLv2 or later, see file LICENSE in this source tree.
 */

/* This might be useful elsewhere */
static unsigned char *hash_bin_to_hex(unsigned char *hash_value,
				unsigned hash_length)
{
	static char hex_value[16*2+1];
	bin2hex(hex_value, (char*)hash_value, hash_length);
	return (unsigned char *)hex_value;
}

static char *unrock(const char *name)
{
	static char buffer[256];
	char *out = buffer;
	int i, j;
	for (i = 0, j = 8; *name && (buffer + 255) > (out + i); name++) {
		if (*name == '/') {
			out[i++] = *name;
			out += i;
			i = 0; j = 8;
		}
		else if (*name == '.') {
			if (i > 8) i = 8;
			for (j = 0; j < i; j++)
				if (out[j] == '.') out[j] = '_';
			out[i++] = *name;
			j = i + 3;
		}
		else if (i >= j) continue;
		else if ((*name >= 'A' && *name <= 'Z') || *name == '_' ||
		    (*name >= '0' && *name <= '9'))
			out[i++] = *name;
		else if (*name >= 'a' && *name <= 'z')
			out[i++] = *name + 'A' - 'a';
		else out[i++] = '_';
	}
	out[i] = 0;
	return buffer;
}

static uint8_t *hash_file(const char *filename)
{
	int src_fd, count;
	md5_ctx_t context;
	uint8_t *hash_value, in_buf[4096];

	src_fd = open(filename, O_RDONLY);
	if (src_fd < 0) {
		src_fd = open(unrock(filename), O_RDONLY);
	}
	if (src_fd < 0) {
		return NULL;
	}

	md5_begin(&context);
	while ((count = read(src_fd, in_buf, 4096)) > 0) {
		md5_hash(&context, in_buf, count);
	}
	hash_value = NULL;
	if (count == 0) {
		md5_end(&context, in_buf);
		hash_value = hash_bin_to_hex(in_buf, 16);
	}

	close(src_fd);

	return hash_value;
}

int main(int argc, char **argv)
{
	int return_value = EXIT_SUCCESS;

	(void) argc;
	/* -c implied */
	openconsole(&dev_rawcon_r, &dev_stdcon_w);

	do {
		FILE *fp;
		char *line, buffer[256];
		fp = fopen(*argv,"r");
		if (fp == NULL)
			fp = fopen(unrock(*argv),"r");

		while ((line = fgets(buffer,256,fp)) != NULL) {
			uint8_t *hash_value;
			char *filename_ptr, *status;
			int len = strlen(line);
#define BLANK "                                "

			if (line[0] < '0')
				continue;
			if (line[len-1] == '\n')
				line[len-1] = 0;
			filename_ptr = strstr(line, "  ");
			/* handle format for binary checksums */
			if (filename_ptr == NULL) {
				filename_ptr = strstr(line, " *");
			}
			if (filename_ptr == NULL) {
				return_value = EXIT_FAILURE;
				continue;
			}
			*filename_ptr = '\0';
			*++filename_ptr = '/';
			if (filename_ptr[1] == '/')
				filename_ptr++;

			status = "NOT CHECKED" BLANK "\n";
			hash_value = hash_file(filename_ptr);
			if (hash_value) {
				status = "OK" BLANK;
				if (strcmp((char*)hash_value, line)) {
					return_value = EXIT_FAILURE;
					status = "FAILED" BLANK "\n";
				}
			}
			printf("\r%s: %s", filename_ptr, status);
		}
		fclose(fp);
	} while (*++argv);
	printf("\r" BLANK "\r");

	return return_value;
}
