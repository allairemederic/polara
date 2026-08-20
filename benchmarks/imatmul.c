// ======================================================
// IMATMUL MEDE TEST
// Single-file standalone benchmark for Polara/Ara FPGA
// ======================================================

#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>

// ======================================================
// DDR ADDRESSES
// ======================================================

#define RESULT_ADDR 0x88000000UL
#define EVICT_ADDR  0x89000000UL

// ======================================================
// TIMER SECTION
// Replaces runtime.h
// ======================================================

static inline int64_t get_cycle_count() {
    int64_t cycle_count;
    asm volatile(
        "fence; csrr %0, cycle"
        : "=r"(cycle_count)
    );
    return cycle_count;
}

// ======================================================
// BENCHMARK CONFIG
// ======================================================

#define NR_LANES 4
#define MAX_DIM 128

#define MIN(a, b) ((a) < (b) ? (a) : (b))

// ======================================================
// MATRICES
// Static allocation to avoid stack usage on FPGA
// ======================================================

int64_t a[MAX_DIM * MAX_DIM];
int64_t b[MAX_DIM * MAX_DIM];

int64_t c[MAX_DIM * MAX_DIM];
int64_t gold[MAX_DIM * MAX_DIM];

// ======================================================
// FILL MATRIX
// ======================================================

void fill_matrix(int64_t *m, int rows, int cols)
{
    for (int i = 0; i < rows * cols; i++) {

        // Small bounded values
        // Keeps numbers readable and avoids overflow
        m[i] = (i % 7) - 3;
    }
}

// ======================================================
// CLEAR MATRIX
// ======================================================

void clear_matrix(int64_t *m, int rows, int cols)
{
    for (int i = 0; i < rows * cols; i++) {
        m[i] = 0;
    }
}

// ======================================================
// VERIFY MATRIX
// ======================================================

int verify_matrix(int64_t *result, int64_t *gold, int rows, int cols)
{
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            int idx = i * cols + j;
            if (result[idx] != gold[idx]) {
                return idx;
            }
        }
    }
    return 0;
}

// ======================================================
// CHECKSUM FOR LARGE MATRICES
// ======================================================

int64_t checksum_matrix(const int64_t *m, int rows, int cols)
{
    int64_t sum = 0;

    for (int i = 0; i < rows * cols; i++) {
        sum += m[i];
    }

    return sum;
}

// ======================================================
// PRINT MATRIX (for debug purpose)
// ======================================================

void print_matrix(const int64_t *m, int rows, int cols)
{
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            printf("%ld ", m[i * cols + j]);
        }
        printf("\n");
    }
}

// ======================================================
// SCALAR REFERENCE
// ======================================================

void imatmul_scalar(int64_t *c, const int64_t *a, const int64_t *b, int M, int N, int P)
{
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < P; j++) {
            int64_t sum = 0;
            for (int k = 0; k < N; k++) {
                sum += a[i * N + k] * b[k * P + j];
            }
            c[i * P + j] = sum;
        }
    }
}

// ======================================================
// 4x4 VECTOR KERNEL
// ======================================================

void imatmul_vec_4x4_slice_init()
{
    asm volatile("vmv.v.i v0, 0");
    asm volatile("vmv.v.i v4, 0");
    asm volatile("vmv.v.i v8, 0");
    asm volatile("vmv.v.i v12, 0");
}

void imatmul_vec_4x4(int64_t *c, const int64_t *a, const int64_t *b, const unsigned long int N, const unsigned long int P)
{
    int64_t t0, t1, t2, t3;
    const int64_t *a_ = a;
    asm volatile("vle64.v v16, (%0);" :: "r"(b));

    b += P;

    t0 = *a; a += N;
    t1 = *a; a += N;
    t2 = *a; a += N;
    t3 = *a;

    unsigned long int n = 0;

    while (n < N) {

        a = a_ + ++n;

        asm volatile("vmacc.vx v0, %0, v16" :: "r"(t0));
        t0 = *a; a += N;

        asm volatile("vle64.v v20, (%0);" :: "r"(b));
        b += P;

        asm volatile("vmacc.vx v4, %0, v16" :: "r"(t1));
        t1 = *a; a += N;

        asm volatile("vmacc.vx v8, %0, v16" :: "r"(t2));
        t2 = *a; a += N;

        asm volatile("vmacc.vx v12, %0, v16" :: "r"(t3));
        t3 = *a;

        a = a_ + ++n;

        if (n == N)
            break;

        asm volatile("vmacc.vx v0, %0, v20" :: "r"(t0));
        t0 = *a; a += N;

        asm volatile("vle64.v v16, (%0);" :: "r"(b));
        b += P;

        asm volatile("vmacc.vx v4, %0, v20" :: "r"(t1));
        t1 = *a; a += N;

        asm volatile("vmacc.vx v8, %0, v20" :: "r"(t2));
        t2 = *a; a += N;

        asm volatile("vmacc.vx v12, %0, v20" :: "r"(t3));
        t3 = *a;
    }

    asm volatile("vmacc.vx v0, %0, v20" :: "r"(t0));
    asm volatile("vse64.v v0, (%0);" :: "r"(c));

    c += P;

    asm volatile("vmacc.vx v4, %0, v20" :: "r"(t1));
    asm volatile("vse64.v v4, (%0);" :: "r"(c));

    c += P;

    asm volatile("vmacc.vx v8, %0, v20" :: "r"(t2));
    asm volatile("vse64.v v8, (%0);" :: "r"(c));

    c += P;

    asm volatile("vmacc.vx v12, %0, v20" :: "r"(t3));
    asm volatile("vse64.v v12, (%0);" :: "r"(c));
}

void imatmul_4x4(int64_t *c, const int64_t *a, const int64_t *b, const unsigned long int M,const unsigned long int N,const unsigned long int P)
{
    const unsigned long int block_size = 4;
    unsigned long int block_size_p;

    asm volatile(
        "vsetvli %0, %1, e64, m4, ta, ma"
        : "=r"(block_size_p)
        : "r"(P)
    );

    for (unsigned long int p = 0; p < P; p += block_size_p) {

        const unsigned long int p_ = MIN(P - p, block_size_p);
        const int64_t *b_ = b + p;
        int64_t *c_ = c + p;

        asm volatile(
            "vsetvli zero, %0, e64, m4, ta, ma"
            :
            : "r"(p_)
        );

        for (unsigned long int m = 0; m < M; m += block_size) {
            const int64_t *a_ = a + m * N;
            int64_t *c__ = c_ + m * P;
            imatmul_vec_4x4_slice_init();
            imatmul_vec_4x4(c__, a_, b_, N, P);
        }
    }
}

// ======================================================
// 8x8 VECTOR KERNEL
// ======================================================

void imatmul_vec_8x8_slice_init()
{
    asm volatile("vmv.v.i v0,  0");
    asm volatile("vmv.v.i v2,  0");
    asm volatile("vmv.v.i v4,  0");
    asm volatile("vmv.v.i v6,  0");
    asm volatile("vmv.v.i v8,  0");
    asm volatile("vmv.v.i v10, 0");
    asm volatile("vmv.v.i v12, 0");
    asm volatile("vmv.v.i v14, 0");
}

void imatmul_vec_8x8(
    int64_t *c,
    const int64_t *a,
    const int64_t *b,
    const unsigned long int N,
    const unsigned long int P)
{
    // Temporary scalars
    int64_t t0, t1, t2, t3;
    int64_t t4, t5, t6, t7;

    // Original A pointer
    const int64_t *a_ = a;

    // Prefetch first row of B
    asm volatile(
        "vle64.v v18, (%0);"
        :
        : "r"(b)
    );

    b += P;

    // Prefetch scalar values
    t0 = *a; a += N;
    t1 = *a; a += N;
    t2 = *a; a += N;
    t3 = *a; a += N;
    t4 = *a; a += N;
    t5 = *a; a += N;
    t6 = *a; a += N;
    t7 = *a;

    unsigned long int n = 0;

    while (n < N) {

        // Move to next column of A
        a = a_ + ++n;

        // Accumulate using v18
        asm volatile("vmacc.vx v0, %0, v18" :: "r"(t0));
        t0 = *a; a += N;

        // Load next row of B
        asm volatile(
            "vle64.v v20, (%0);"
            :
            : "r"(b)
        );

        b += P;

        asm volatile("vmacc.vx v2, %0, v18" :: "r"(t1));
        t1 = *a; a += N;

        asm volatile("vmacc.vx v4, %0, v18" :: "r"(t2));
        t2 = *a; a += N;

        asm volatile("vmacc.vx v6, %0, v18" :: "r"(t3));
        t3 = *a; a += N;

        asm volatile("vmacc.vx v8, %0, v18" :: "r"(t4));
        t4 = *a; a += N;

        asm volatile("vmacc.vx v10, %0, v18" :: "r"(t5));
        t5 = *a; a += N;

        asm volatile("vmacc.vx v12, %0, v18" :: "r"(t6));
        t6 = *a; a += N;

        asm volatile("vmacc.vx v14, %0, v18" :: "r"(t7));
        t7 = *a;

        a = a_ + ++n;

        if (n == N)
            break;

        // Accumulate using v20
        asm volatile("vmacc.vx v0, %0, v20" :: "r"(t0));
        t0 = *a; a += N;

        // Load next row of B
        asm volatile(
            "vle64.v v18, (%0);"
            :
            : "r"(b)
        );

        b += P;

        asm volatile("vmacc.vx v2, %0, v20" :: "r"(t1));
        t1 = *a; a += N;

        asm volatile("vmacc.vx v4, %0, v20" :: "r"(t2));
        t2 = *a; a += N;

        asm volatile("vmacc.vx v6, %0, v20" :: "r"(t3));
        t3 = *a; a += N;

        asm volatile("vmacc.vx v8, %0, v20" :: "r"(t4));
        t4 = *a; a += N;

        asm volatile("vmacc.vx v10, %0, v20" :: "r"(t5));
        t5 = *a; a += N;

        asm volatile("vmacc.vx v12, %0, v20" :: "r"(t6));
        t6 = *a; a += N;

        asm volatile("vmacc.vx v14, %0, v20" :: "r"(t7));
        t7 = *a;
    }

    // Final accumulation + stores

    asm volatile("vmacc.vx v0, %0, v20" :: "r"(t0));
    asm volatile("vse64.v v0, (%0);" :: "r"(c));

    c += P;

    asm volatile("vmacc.vx v2, %0, v20" :: "r"(t1));
    asm volatile("vse64.v v2, (%0);" :: "r"(c));

    c += P;

    asm volatile("vmacc.vx v4, %0, v20" :: "r"(t2));
    asm volatile("vse64.v v4, (%0);" :: "r"(c));

    c += P;

    asm volatile("vmacc.vx v6, %0, v20" :: "r"(t3));
    asm volatile("vse64.v v6, (%0);" :: "r"(c));

    c += P;

    asm volatile("vmacc.vx v8, %0, v20" :: "r"(t4));
    asm volatile("vse64.v v8, (%0);" :: "r"(c));

    c += P;

    asm volatile("vmacc.vx v10, %0, v20" :: "r"(t5));
    asm volatile("vse64.v v10, (%0);" :: "r"(c));

    c += P;

    asm volatile("vmacc.vx v12, %0, v20" :: "r"(t6));
    asm volatile("vse64.v v12, (%0);" :: "r"(c));

    c += P;

    asm volatile("vmacc.vx v14, %0, v20" :: "r"(t7));
    asm volatile("vse64.v v14, (%0);" :: "r"(c));
}

void imatmul_8x8(int64_t *c, const int64_t *a, const int64_t *b, const unsigned long int M, const unsigned long int N, const unsigned long int P)
{
    // We work on 8 rows at once
    const unsigned long int block_size = 8;

    unsigned long int block_size_p;

    // Set vector configuration
    asm volatile(
        "vsetvli %0, %1, e64, m2, ta, ma"
        : "=r"(block_size_p)
        : "r"(P)
    );

    // Slice matrix columns
    for (unsigned long int p = 0;
         p < P;
         p += block_size_p) {

        const unsigned long int p_ =
            MIN(P - p, block_size_p);

        const int64_t *b_ = b + p;

        int64_t *c_ = c + p;

        asm volatile(
            "vsetvli zero, %0, e64, m2, ta, ma"
            :
            : "r"(p_)
        );

        // Iterate over rows
        for (unsigned long int m = 0; m < M; m += block_size) {
            const int64_t *a_ = a + m * N;
            int64_t *c__ = c_ + m * P;
            imatmul_vec_8x8_slice_init();
            imatmul_vec_8x8(c__,  a_, b_, N, P);
        }
    }
}

// ======================================================
// IMATMUL MAIN DISPATCH
// ======================================================

void imatmul(int64_t *c, const int64_t *a, const int64_t *b, const unsigned long int M, const unsigned long int N, const unsigned long int P)
{
    if (M <= 4) {
        imatmul_4x4(c, a, b, M, N, P);
    } else if (M <= 128) {
        imatmul_8x8(c, a, b, M, N, P);
    } else {
        imatmul_4x4(c, a, b, M, N, P);
    }
}

// ======================================================
// MAIN
// ======================================================

int main(int argc, char ** argv)
{
    // For DDR
    volatile uint64_t *results = (volatile uint64_t *)RESULT_ADDR;
    volatile uint64_t *evict = (volatile uint64_t *)EVICT_ADDR;

    // Matrix size
    int sizes[] = {4, 8, 16, 32, 64, 128};
    int result_idx = 0;

    for (int size_idx = 0; size_idx < 6; size_idx++) {

        int s = sizes[size_idx];

        fill_matrix(a, s, s);
        fill_matrix(b, s, s);

        clear_matrix(c, s, s);
        clear_matrix(gold, s, s);

        imatmul_scalar(gold, a, b, s, s, s);

        for (int iter = 0; iter < 16; iter++) {

            clear_matrix(c, s, s);

            uint64_t start = get_cycle_count();
            imatmul(c, a, b, s, s, s);
            uint64_t end = get_cycle_count();

            results[result_idx++] = s;
            results[result_idx++] = end - start;
            results[result_idx++] = verify_matrix(c, gold, s, s);
        }
    }

    // Temporary cache eviction workaround
    for (int i = 0; i < (1024 * 1024 / 8); i++)
    {
        evict[i] = i;
    }

    // Keep CPU alive on FPGA
    while (1);

    return 0;
}
