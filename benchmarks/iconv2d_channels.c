// ======================================================
// ICONV2D MEDE TEST
// Single-file standalone benchmark for Polara/Ara FPGA
// ======================================================

#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>

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
// TEST CONFIG SECTION
// ======================================================

typedef struct
{
    int filter_size;
    int matrix_size;
    int channels;
} test_config_t;

// ======================================================
// BENCHMARK CONFIG
// ======================================================

#define MAX_IFMAP 512
#define MAX_F     7

#define MAX_INPUT_ROWS (MAX_IFMAP + MAX_F)
#define MAX_INPUT_COLS (MAX_IFMAP + MAX_F)

#define MAX_CHANNELS 16

#define MIN(a,b) ((a)<(b)?(a):(b))

int64_t i[MAX_CHANNELS][MAX_INPUT_ROWS * MAX_INPUT_COLS];
int64_t f[MAX_CHANNELS][MAX_F * MAX_F];

int64_t o[MAX_IFMAP * MAX_IFMAP];
int64_t temp_o[MAX_IFMAP * MAX_IFMAP];
int64_t golden_o[MAX_IFMAP * MAX_IFMAP];


// ======================================================
// ADD MATRIX
// ======================================================

void add_matrix(int64_t *dst, int64_t *src, int rows, int cols)
{
    for (int i = 0; i < rows * cols; i++)
        dst[i] += src[i];
}

// ======================================================
// FILL MATRIX
// ======================================================

void fill_matrix(int64_t *m, int rows, int cols)
{
    for (int i = 0; i < rows * cols; i++) {
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
// SCALAR REFERENCE
// ======================================================

void iconv2d_scalar(
    int64_t *o, 
    const int64_t i[MAX_CHANNELS][MAX_INPUT_ROWS * MAX_INPUT_COLS],
    const int64_t f[MAX_CHANNELS][MAX_F * MAX_F],
    int64_t M_, 
    int64_t N_, 
    int64_t F_, 
    int64_t input_cols, 
    int64_t channels)
{
    for (int r = 0; r < M_; r++) {
        for (int c = 0; c < N_; c++) {
            int64_t sum = 0;

            // For input channels support
            for (int ch = 0; ch < channels; ch++){

                const int64_t *i_ch = i[ch];
                const int64_t *f_ch = f[ch];

                for (int fr = 0; fr < F_; fr++) {
                    for (int fc = 0; fc < F_; fc++) {
                        int64_t input = i_ch[(r + fr) * input_cols + (c + fc)];
                        int64_t coeff = f_ch[fr * F_ + fc];
                        sum += input * coeff;
                    }
                }

            }

            o[r * N_ + c] = sum;
        }
    }
}

// ======================================================
// KERNEL 3x3
// ======================================================

void iconv2d_vec_4xC_slice_preload_3x3(int64_t *i, int64_t C, int64_t F_arg) {
  // Helper variables
  int64_t ldi = (C + F_arg - 1) << 3;

  // Set the vector configuration
  asm volatile("vsetvli zero, %0, e64, m2, ta, ma" ::"r"(C + F_arg - 1));
  // Fetch the first floor(F/2) + 1 input rows
  asm volatile("vle64.v v8,  (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi));
  asm volatile("vle64.v v10, (%0); add %0, %0, %1" : "+r"(i));
}

void iconv2d_vec_4xC_slice_move_3x3(int64_t C, int64_t F_arg) {
  // Move C+F-1 elements
  asm volatile("vsetvli zero, %0, e64, m2, ta, ma" ::"r"(C + F_arg - 1));
  // Move the last floor(F/2) + 1 input rows
  asm volatile("vmv.v.v v8, v16");
  asm volatile("vmv.v.v v10, v18");
}

void iconv2d_vec_4xC_3x3(int64_t *o, int64_t *i, int64_t *f, int64_t C, int64_t F_arg) {

  // Temporary variables
  int64_t t0, t1, t2;

  // Helper variables
  int64_t ldo = C << 3;
  int64_t ldi = (C + F_arg - 1) << 3;
  int64_t ldf = F_arg << 3;
  int64_t *f_;

  // Fetch C + F - 1 elements (padding included)
  asm volatile("vsetvli zero, %0, e64, m2, ta, ma" ::"r"(C + F_arg - 1));
  f_ = f;
  // Fetch the first column of the filter, and start calculating its
  // contribution on the four output rows (v0, v2, v4, v6)
  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t0) : "r"(ldf));
  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t1) : "r"(ldf));
  asm volatile("ld %1, (%0);" : "+&r"(f_), "=&r"(t2));

  // Fetch 4 + F - 1 - 2 rows of the input matrix
  // Compute on C + F - 1 elements, instead of C elements, to cover the latency
  // of the load instructions
  asm volatile("vle64.v v12, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi));
  asm volatile("vmul.vx v0, v8, %0" ::"r"(t0));

  asm volatile("vmul.vx v2, v10, %0" ::"r"(t0));
  asm volatile("vle64.v v14, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi));
  asm volatile("vmacc.vx v0, %0, v10" ::"r"(t1));

  asm volatile("vmacc.vx v2, %0, v12" ::"r"(t1));
  asm volatile("vle64.v v16, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi));
  asm volatile("vmacc.vx v0, %0, v12" ::"r"(t2));
  asm volatile("vslidedown.vi v20, v8,  1");
  asm volatile("vmul.vx v4, v12, %0" ::"r"(t0));

  asm volatile("vle64.v v18, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi));

  asm volatile("vsetvli zero, %0, e64, m2, ta, ma" ::"r"(C));

  asm volatile("vmul.vx v6, v14, %0" ::"r"(t0));
  asm volatile("vmacc.vx v4, %0, v14" ::"r"(t1));
  asm volatile("vslidedown.vi v22, v10, 1");
  asm volatile("vmacc.vx v2, %0, v14" ::"r"(t2));

  asm volatile("vmacc.vx v6, %0, v16" ::"r"(t1));
  asm volatile("vmacc.vx v4, %0, v16" ::"r"(t2));

  asm volatile("vslidedown.vi v24, v12, 1");
  asm volatile("vmacc.vx v6, %0, v18" ::"r"(t2));

  f_ = f + 1;
  // Fetch the middle column of the filter, and start calculating its
  // contributions on the output rows To do so, slide down the input rows by one
  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t0) : "r"(ldf));
  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t1) : "r"(ldf));
  asm volatile("ld %1, (%0);" : "+&r"(f_), "=&r"(t2));

  asm volatile("vmacc.vx v0, %0, v20" ::"r"(t0));

  asm volatile("vmacc.vx v0, %0, v22" ::"r"(t1));
  asm volatile("vslidedown.vi v26, v14, 1");
  asm volatile("vmacc.vx v2, %0, v22" ::"r"(t0));

  asm volatile("vmacc.vx v0, %0, v24" ::"r"(t2));
  asm volatile("vmacc.vx v2, %0, v24" ::"r"(t1));
  asm volatile("vslidedown.vi v28, v16, 1");
  asm volatile("vmacc.vx v4, %0, v24" ::"r"(t0));

  asm volatile("vmacc.vx v2, %0, v26" ::"r"(t2));
  asm volatile("vmacc.vx v4, %0, v26" ::"r"(t1));
  asm volatile("vslidedown.vi v30, v18, 1");
  asm volatile("vmacc.vx v6, %0, v26" ::"r"(t0));

  asm volatile("vmacc.vx v4, %0, v28" ::"r"(t2));
  asm volatile("vslidedown.vi v20, v8,  2");
  asm volatile("vmacc.vx v6, %0, v28" ::"r"(t1));

  asm volatile("vmacc.vx v6, %0, v30" ::"r"(t2));
  asm volatile("vslidedown.vi v22, v10, 2");

  f_ = f + 2;
  // Repeat for the last filter column, and then store the output rows
  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t0) : "r"(ldf));
  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t1) : "r"(ldf));
  asm volatile("ld %1, (%0);" : "+&r"(f_), "=&r"(t2));

  asm volatile("vmacc.vx v0, %0, v20" ::"r"(t0));

  asm volatile("vmacc.vx v0, %0, v22" ::"r"(t1));
  asm volatile("vslidedown.vi v24, v12, 2");
  asm volatile("vmacc.vx v2, %0, v22" ::"r"(t0));

  // Compute on C elements

  asm volatile("vmacc.vx v0, %0, v24" ::"r"(t2));
  asm volatile("vse64.v  v0, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));
  asm volatile("vslidedown.vi v26, v14, 2");
  asm volatile("vmacc.vx v2, %0, v24" ::"r"(t1));
  asm volatile("vmacc.vx v4, %0, v24" ::"r"(t0));

  asm volatile("vmacc.vx v2, %0, v26" ::"r"(t2));
  asm volatile("vse64.v  v2, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));
  asm volatile("vslidedown.vi v28, v16, 2");
  asm volatile("vmacc.vx v4, %0, v26" ::"r"(t1));
  asm volatile("vmacc.vx v6, %0, v26" ::"r"(t0));

  asm volatile("vmacc.vx v4, %0, v28" ::"r"(t2));
  asm volatile("vslidedown.vi v30, v18, 2");
  asm volatile("vse64.v  v4, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));
  asm volatile("vmacc.vx v6, %0, v28" ::"r"(t1));

  asm volatile("vmacc.vx v6, %0, v30" ::"r"(t2));
  asm volatile("vse64.v  v6, (%0);" : "+r"(o));
}

void iconv2d_3x3(int64_t *o, int64_t *i, int64_t *f, int64_t R, int64_t C, int64_t F_arg) {
  // We work on 4 rows of the output matrix at once
  int64_t block_size_o = 4;
  // We work on block_size_o + F - 1 rows of the input matrix at once

  // First iteration round, r = 0
  int64_t *i_ = i;
  int64_t *o_ = o;

  // Preload the first two input rows -> This is not needed in the other rounds
  iconv2d_vec_4xC_slice_preload_3x3(i_, C, F_arg);
  // The first F-1 rows have already been loaded by
  // iconv2d_vec_4xC_slice_preload_3x3()
  int64_t *i__ = i_ + (F_arg - 1) * (C + F_arg - 1);
  iconv2d_vec_4xC_3x3(o_, i__, f, C, F_arg);
  // Re-use some of the already-loaded input rows
  iconv2d_vec_4xC_slice_move_3x3(C, F_arg);

  i_ = i + block_size_o * (C + F_arg - 1);
  i__ = i_ + (F_arg - 1) * (C + F_arg - 1);

  int64_t ldi = (C + F_arg - 1) << 3;
  int64_t ldf = F_arg << 3;

  // Temporary variables
  int64_t t0, t1, t2;
  // Helper variables
  int64_t *f_;
  f_ = f;
  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t0) : "r"(ldf));
  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t1) : "r"(ldf));
  asm volatile("ld %1, (%0);" : "+&r"(f_), "=&r"(t2));

  // Iterate over the output rows
  for (int64_t r = block_size_o; r < R; r += block_size_o) {

    // The first F-1 rows have already been loaded by
    // iconv2d_vec_4xC_slice_init()

    int64_t t3, t4, t5;

    // Fetch C + F - 1 elements (padding included)
    asm volatile("vsetvli zero, %0, e64, m2, ta, ma" ::"r"(C + F_arg - 1));
    f_ = f;

    // Fetch the first column of the filter, and start calculating its
    // contribution on the four output rows (v0, v2, v4, v6)

    // Fetch 4 + F - 1 - 2 rows of the input matrix
    // Compute on C + F - 1 elements, instead of C elements, to cover the
    // latency of the load instructions
    asm volatile("vmv.v.v v8, v16");
    asm volatile("vle64.v v12, (%0); add %0, %0, %1" : "+&r"(i__) : "r"(ldi));
    asm volatile("vmul.vx v0, v8, %0" ::"r"(t0));

    asm volatile("vmv.v.v v10, v18");
    asm volatile("vmul.vx v2, v10, %0" ::"r"(t0));
    asm volatile("vle64.v v14, (%0); add %0, %0, %1" : "+&r"(i__) : "r"(ldi));
    asm volatile("vmacc.vx v0, %0, v10" ::"r"(t1));

    asm volatile("vmacc.vx v2, %0, v12" ::"r"(t1));
    asm volatile("vle64.v v16, (%0); add %0, %0, %1" : "+&r"(i__) : "r"(ldi));
    asm volatile("vmacc.vx v0, %0, v12" ::"r"(t2));
    asm volatile("vslidedown.vi v20, v8,  1");
    asm volatile("vmul.vx v4, v12, %0" ::"r"(t0));

    asm volatile("vle64.v v18, (%0); add %0, %0, %1" : "+&r"(i__) : "r"(ldi));

    asm volatile("vsetvli zero, %0, e64, m2, ta, ma" ::"r"(C));

    asm volatile("vmul.vx v6, v14, %0" ::"r"(t0));
    asm volatile("vslidedown.vi v22, v10, 1");
    asm volatile("vmacc.vx v4, %0, v14" ::"r"(t1));
    asm volatile("vmacc.vx v2, %0, v14" ::"r"(t2));
    asm volatile("vslidedown.vi v24, v12, 1");

    asm volatile("vmacc.vx v6, %0, v16" ::"r"(t1));
    asm volatile("vmacc.vx v4, %0, v16" ::"r"(t2));

    asm volatile("vslidedown.vi v26, v14, 1");

    asm volatile("vmacc.vx v6, %0, v18" ::"r"(t2));

    f_ = f + 1;
    // Fetch the middle column of the filter, and start calculating its
    // contributions on the output rows To do so, slide down the input rows by
    // one
    asm volatile("ld %1, (%0); add %0, %0, %2"
                 : "+&r"(f_), "=&r"(t3)
                 : "r"(ldf));
    asm volatile("ld %1, (%0); add %0, %0, %2"
                 : "+&r"(f_), "=&r"(t4)
                 : "r"(ldf));
    asm volatile("ld %1, (%0);" : "+&r"(f_), "=&r"(t5));

    asm volatile("vmacc.vx v0, %0, v20" ::"r"(t3));

    asm volatile("vmacc.vx v0, %0, v22" ::"r"(t4));
    asm volatile("vslidedown.vi v28, v16, 1");
    asm volatile("vmacc.vx v2, %0, v22" ::"r"(t3));

    i_ = i + (r + block_size_o) * (C + F_arg - 1);
    asm volatile("vmacc.vx v0, %0, v24" ::"r"(t5));
    asm volatile("vslidedown.vi v30, v18, 1");
    asm volatile("vmacc.vx v2, %0, v24" ::"r"(t4));
    asm volatile("vmacc.vx v4, %0, v24" ::"r"(t3));
    asm volatile("vslidedown.vi v20, v8,  2");

    asm volatile("vmacc.vx v2, %0, v26" ::"r"(t5));
    asm volatile("vmacc.vx v4, %0, v26" ::"r"(t4));
    asm volatile("vslidedown.vi v22, v10, 2");
    asm volatile("vmacc.vx v6, %0, v26" ::"r"(t3));
    i__ = i_ + (F_arg - 1) * (C + F_arg - 1);

    asm volatile("vmacc.vx v4, %0, v28" ::"r"(t5));
    f_ = f + 2;
    asm volatile("ld %1, (%0); add %0, %0, %2"
                 : "+&r"(f_), "=&r"(t3)
                 : "r"(ldf));
    asm volatile("vmacc.vx v6, %0, v28" ::"r"(t4));
    asm volatile("vslidedown.vi v24, v12, 2");

    asm volatile("vmacc.vx v6, %0, v30" ::"r"(t5));
    asm volatile("vmacc.vx v0, %0, v20" ::"r"(t3));
    asm volatile("vslidedown.vi v26, v14, 2");

    // Repeat for the last filter column, and then store the output rows
    asm volatile("ld %1, (%0); add %0, %0, %2"
                 : "+&r"(f_), "=&r"(t4)
                 : "r"(ldf));
    asm volatile("ld %1, (%0);" : "+&r"(f_), "=&r"(t5));

    asm volatile("vmacc.vx v0, %0, v22" ::"r"(t4));
    o_ = o + r * C;

    // Compute on C elements
    int64_t ldo = C << 3;
    asm volatile("vmacc.vx v2, %0, v22" ::"r"(t3));
    asm volatile("vslidedown.vi v28, v16, 2");

    asm volatile("vmacc.vx v0, %0, v24" ::"r"(t5));
    asm volatile("vmacc.vx v2, %0, v24" ::"r"(t4));
    asm volatile("vslidedown.vi v30, v18, 2");
    asm volatile("vse64.v  v0, (%0); add %0, %0, %1" : "+&r"(o_) : "r"(ldo));
    asm volatile("vmacc.vx v4, %0, v24" ::"r"(t3));

    asm volatile("vmacc.vx v2, %0, v26" ::"r"(t5));
    asm volatile("vse64.v  v2, (%0); add %0, %0, %1" : "+&r"(o_) : "r"(ldo));
    asm volatile("vmacc.vx v4, %0, v26" ::"r"(t4));
    asm volatile("vmacc.vx v6, %0, v26" ::"r"(t3));

    asm volatile("vmacc.vx v4, %0, v28" ::"r"(t5));
    asm volatile("vse64.v  v4, (%0); add %0, %0, %1" : "+&r"(o_) : "r"(ldo));
    asm volatile("vmacc.vx v6, %0, v28" ::"r"(t4));

    asm volatile("vmacc.vx v6, %0, v30" ::"r"(t5));
    asm volatile("vse64.v  v6, (%0);" : "+r"(o_));
  }
}

// ======================================================
// KERNEL 5x5
// ======================================================

// Load 4 rows of the output matrix
void iconv2d_vec_4xC_slice_init_5x5(int64_t *o, int64_t C) {
  // Helper variables
  int64_t ldo = C << 3;

  // Set the vector configuration
  asm volatile("vsetvli zero, %0, e64, m2, ta, ma" ::"r"(C));
  // Fetch 2 output rows
  asm volatile("vmv.v.i v0,  0; add %0, %0, %1" : "+&r"(o) : "r"(ldo));
  asm volatile("vmv.v.i v2,  0;" : "+r"(o));
}

// Load 4 rows of the output matrix
void iconv2d_vec_4xC_slice_preload_5x5(int64_t *i, int64_t C, int64_t F_arg) {
  // Helper variables
  int64_t ldi = (C + F_arg - 1) << 3;

  // Set the vector configuration
  asm volatile("vsetvli zero, %0, e64, m2, ta, ma" ::"r"(C + F_arg - 1));
  // Fetch the first F-1 = 4 input rows
  asm volatile("vle64.v v4, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi));
  asm volatile("vle64.v v6, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi));
  asm volatile("vle64.v v8, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi));
  asm volatile("vle64.v v10, (%0); add %0, %0, %1" : "+r"(i));
}

// Calculate 4 output matrix rows
void iconv2d_vec_4xC_5x5(int64_t *o, int64_t *i, int64_t *f, int64_t C, int64_t F_arg) {

  // Temporary variables (one filter column)
  int64_t t0, t1, t2, t3, t4;
  int64_t slamt;

  // Helper variables
  int64_t ldo = C << 3;
  int64_t ldi = (C + F_arg - 1) << 3;
  int64_t ldf = F_arg << 3;
  int64_t *f_;

  // Compute on C elements
  asm volatile("vsetvli zero, %0, e64, m2, ta, ma" ::"r"(C + F_arg - 1));
  // Fetch other 2 rows of the input matrix
  asm volatile("vle64.v v12, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi));
  asm volatile("vle64.v v14, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi));

  // Compute on C elements
  asm volatile("vsetvli zero, %0, e64, m2, ta, ma" ::"r"(C));
  f_ = f;
  // Fetch the first column of the filter, and start calculating its
  // contribution on the two output rows (v0, v2)
  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t0) : "r"(ldf));
  asm volatile("vmacc.vx v0, %0, v4" ::"r"(t0));
  asm volatile("vmacc.vx v2, %0, v6" ::"r"(t0));

  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t1) : "r"(ldf));
  asm volatile("vmacc.vx v0, %0, v6" ::"r"(t1));
  asm volatile("vmacc.vx v2, %0, v8" ::"r"(t1));

  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t2) : "r"(ldf));
  asm volatile("vmacc.vx v0, %0, v8" ::"r"(t2));
  asm volatile("vmacc.vx v2, %0, v10" ::"r"(t2));

  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t3) : "r"(ldf));
  asm volatile("vmacc.vx v0, %0, v10" ::"r"(t3));
  asm volatile("vmacc.vx v2, %0, v12" ::"r"(t3));

  asm volatile("ld %1, (%0);" : "+&r"(f_), "=&r"(t4));
  asm volatile("vmacc.vx v0, %0, v12" ::"r"(t4));
  asm volatile("vmacc.vx v2, %0, v14" ::"r"(t4));

  for (int64_t idx = 1; idx < F_arg - 1; ++idx) {
    // Adjust filter mtx pointer and slide-amount
    f_ = f + idx;
    slamt = idx;
    // Fetch the other columns of the filter (except for the last one), and
    // start calculating their contributions on the two output rows (v0, v2) To
    // do so, at each iteration slide down the input rows by one
    asm volatile("ld %1, (%0); add %0, %0, %2"
                 : "+&r"(f_), "=&r"(t0)
                 : "r"(ldf));
    asm volatile("vslidedown.vx v16, v4,  %0" ::"r"(slamt));
    asm volatile("vmacc.vx v0, %0, v16" ::"r"(t0));

    asm volatile("ld %1, (%0); add %0, %0, %2"
                 : "+&r"(f_), "=&r"(t1)
                 : "r"(ldf));
    asm volatile("vslidedown.vx v18, v6,  %0" ::"r"(slamt));
    asm volatile("vmacc.vx v0, %0, v18" ::"r"(t1));
    asm volatile("vmacc.vx v2, %0, v18" ::"r"(t0));

    asm volatile("ld %1, (%0); add %0, %0, %2"
                 : "+&r"(f_), "=&r"(t2)
                 : "r"(ldf));
    asm volatile("vslidedown.vx v20, v8,  %0" ::"r"(slamt));
    asm volatile("vmacc.vx v0, %0, v20" ::"r"(t2));
    asm volatile("vmacc.vx v2, %0, v20" ::"r"(t1));

    asm volatile("ld %1, (%0); add %0, %0, %2"
                 : "+&r"(f_), "=&r"(t3)
                 : "r"(ldf));
    asm volatile("vslidedown.vx v22, v10, %0" ::"r"(slamt));
    asm volatile("vmacc.vx v0, %0, v22" ::"r"(t3));
    asm volatile("vmacc.vx v2, %0, v22" ::"r"(t2));

    asm volatile("ld %1, (%0);" : "+&r"(f_), "=&r"(t4));
    asm volatile("vslidedown.vx v24, v12, %0" ::"r"(slamt));
    asm volatile("vmacc.vx v0, %0, v24" ::"r"(t4));
    asm volatile("vmacc.vx v2, %0, v24" ::"r"(t3));

    asm volatile("vslidedown.vx v26, v14, %0" ::"r"(slamt));
    asm volatile("vmacc.vx v2, %0, v26" ::"r"(t4));
  }

  f_ = f + (F_arg - 1);
  slamt = (F_arg - 1);
  // Repeat for the last filter column, and then store the output rows
  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t0) : "r"(ldf));
  asm volatile("vslidedown.vx v16, v4,  %0" ::"r"(slamt));
  asm volatile("vmacc.vx v0, %0, v16" ::"r"(t0));

  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t1) : "r"(ldf));
  asm volatile("vslidedown.vx v18, v6,  %0" ::"r"(slamt));
  asm volatile("vmacc.vx v0, %0, v18" ::"r"(t1));
  asm volatile("vmacc.vx v2, %0, v18" ::"r"(t0));

  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t2) : "r"(ldf));
  asm volatile("vslidedown.vx v20, v8,  %0" ::"r"(slamt));
  asm volatile("vmacc.vx v0, %0, v20" ::"r"(t2));
  asm volatile("vmacc.vx v2, %0, v20" ::"r"(t1));

  asm volatile("ld %1, (%0); add %0, %0, %2" : "+&r"(f_), "=&r"(t3) : "r"(ldf));
  asm volatile("vslidedown.vx v22, v10, %0" ::"r"(slamt));
  asm volatile("vmacc.vx v0, %0, v22" ::"r"(t3));
  asm volatile("vmacc.vx v2, %0, v22" ::"r"(t2));

  asm volatile("ld %1, (%0);" : "+&r"(f_), "=&r"(t4));
  asm volatile("vslidedown.vx v24, v12, %0" ::"r"(slamt));
  asm volatile("vmacc.vx v0, %0, v24" ::"r"(t4));
  asm volatile("vse64.v  v0, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));
  asm volatile("vmacc.vx v2, %0, v24" ::"r"(t3));

  asm volatile("vslidedown.vx v26, v14, %0" ::"r"(slamt));
  asm volatile("vmacc.vx v2, %0, v26" ::"r"(t4));
  asm volatile("vse64.v  v2, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));
}

void iconv2d_vec_4xC_slice_move_5x5(int64_t C, int64_t F_arg) {
  // Move C+F-1 elements
  asm volatile("vsetvli zero, %0, e64, m2, ta, ma" ::"r"(C + F_arg - 1));
  // Move the last floor(F/2) + 1 input rows
  asm volatile("vmv.v.v v4, v8");
  asm volatile("vmv.v.v v6, v10");
  asm volatile("vmv.v.v v8, v12");
  asm volatile("vmv.v.v v10, v14");
}

void iconv2d_5x5(int64_t *o, int64_t *i, int64_t *f, int64_t R, int64_t C, int64_t F_arg) {
  // We work on 2 rows of the output matrix at once
  int64_t block_size_o = 2;
  // We work on block_size_o + F - 1 rows of the input matrix at once

  // First iteration round, r = 0
  int64_t *i_ = i;
  int64_t *o_ = o;

  // For simplicity, compute over the padding rows as well
  iconv2d_vec_4xC_slice_init_5x5(o_, C);
  // Preload the first two input rows -> This is not needed in the other rounds
  iconv2d_vec_4xC_slice_preload_5x5(i_, C, F_arg);
  // The first (floor(F/2) + 1 = 2) rows have already been loaded by
  // iconv2d_vec_4xC_slice_init()
  int64_t *i__ = i_ + (F_arg - 1) * (C + F_arg - 1);
  iconv2d_vec_4xC_5x5(o_, i__, f, C, F_arg);
  // Re-use some of the already-loaded input rows
  iconv2d_vec_4xC_slice_move_5x5(C, F_arg);

  // Iterate over the output rows
  for (int64_t r = block_size_o; r < R; r += block_size_o) {
    i_ = i + r * (C + F_arg - 1);
    o_ = o + r * C;

    // For simplicity, compute over the padding rows as well
    iconv2d_vec_4xC_slice_init_5x5(o_, C);
    // The first F-1 rows have already been loaded by
    // iconv2d_vec_4xC_slice_init()
    i__ = i_ + (F_arg - 1) * (C + F_arg - 1);
    iconv2d_vec_4xC_5x5(o_, i__, f, C, F_arg);
    // Re-use some of the already-loaded input rows
    iconv2d_vec_4xC_slice_move_5x5(C, F_arg);
  }
}

// ======================================================
// KERNEL 7x7
// ======================================================

void iconv2d_7x7_block(int64_t *o, int64_t *i, int64_t *f, int64_t R, int64_t C, int64_t n_, int64_t F_arg) {

  // Helper variables
  int64_t ldo = C << 3;
  int64_t ldi_pad = (C + F_arg - 1) << 3;

  int64_t *i_ = i;

  int64_t t6, t13, t20, t27, t34, t41, t48;

  int64_t *i_slide_ptr_0;
  int64_t *i_slide_ptr_1;
  int64_t *i_slide_ptr_2;
  int64_t *i_slide_ptr_3;

  // Buffer some of the filter coefficients not to lose efficiency after a
  // vector store (CVA6 cannot issue memory operations if there is a pending
  // store!)
  t6 = f[6];
  t13 = f[13];
  t20 = f[20];
  t27 = f[27];
  t34 = f[34];
  t41 = f[41];
  t48 = f[48];

  // Point to the scalar elements to insert during a slide
  i_slide_ptr_0 = i + n_ + 0 * (C + F_arg - 1);
  i_slide_ptr_1 = i + n_ + 1 * (C + F_arg - 1);
  i_slide_ptr_2 = i + n_ + 2 * (C + F_arg - 1);
  i_slide_ptr_3 = i + n_ + 3 * (C + F_arg - 1);

  ////////////////
  // Row 0 -> 3 //
  ////////////////

  // Load one input row
  asm volatile("vle64.v v0, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));
  asm volatile("vle64.v v4, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));
  asm volatile("vle64.v v8, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));
  asm volatile("vle64.v v12, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));

  // Main kernel, unrolled by 2
  for (int k = 0; k < F_arg / 2; ++k) {
    if (k == 0)
      asm volatile("vmul.vx v16, v0, %0" ::"r"(f[0 + (2 * k)]));
    else
      asm volatile("vmacc.vx v16, %0, v0" ::"r"(f[0 + (2 * k)]));
    if (k == 0)
      asm volatile("vmul.vx v18, v4, %0" ::"r"(f[0 + (2 * k)]));
    else
      asm volatile("vmacc.vx v18, %0, v4" ::"r"(f[0 + (2 * k)]));
    asm volatile("vslide1down.vx v2, v0, %0" ::"r"(*i_slide_ptr_0++));
    asm volatile("vmacc.vx v16, %0, v4" ::"r"(f[7 + (2 * k)]));
    if (k == 0)
      asm volatile("vmul.vx v22, v12, %0" ::"r"(f[0 + (2 * k)]));
    else
      asm volatile("vmacc.vx v22, %0, v12" ::"r"(f[0 + (2 * k)]));
    asm volatile("vslide1down.vx v6, v4, %0" ::"r"(*i_slide_ptr_1++));
    asm volatile("vmacc.vx v18, %0, v8" ::"r"(f[7 + (2 * k)]));
    asm volatile("vmacc.vx v16, %0, v8" ::"r"(f[14 + (2 * k)]));
    asm volatile("vslide1down.vx v10, v8, %0" ::"r"(*i_slide_ptr_2++));
    if (k == 0)
      asm volatile("vmul.vx v20, v8, %0" ::"r"(f[0 + (2 * k)]));
    else
      asm volatile("vmacc.vx v20, %0, v8" ::"r"(f[0 + (2 * k)]));
    asm volatile("vmacc.vx v18, %0, v12" ::"r"(f[14 + (2 * k)]));
    asm volatile("vmacc.vx v16, %0, v12" ::"r"(f[21 + (2 * k)]));
    asm volatile("vslide1down.vx v14, v12, %0" ::"r"(*i_slide_ptr_3++));
    asm volatile("vmacc.vx v20, %0, v12" ::"r"(f[7 + (2 * k)]));

    asm volatile("vmacc.vx v16, %0, v2" ::"r"(f[0 + (2 * k + 1)]));
    asm volatile("vmacc.vx v18, %0, v6" ::"r"(f[0 + (2 * k + 1)]));
    asm volatile("vslide1down.vx v0, v2, %0" ::"r"(*i_slide_ptr_0++));
    asm volatile("vmacc.vx v16, %0, v6" ::"r"(f[7 + (2 * k + 1)]));
    asm volatile("vmacc.vx v18, %0, v10" ::"r"(f[7 + (2 * k + 1)]));
    asm volatile("vmacc.vx v20, %0, v10" ::"r"(f[0 + (2 * k + 1)]));
    asm volatile("vslide1down.vx v4, v6, %0" ::"r"(*i_slide_ptr_1++));
    asm volatile("vmacc.vx v16, %0, v10" ::"r"(f[14 + (2 * k + 1)]));
    asm volatile("vmacc.vx v18, %0, v14" ::"r"(f[14 + (2 * k + 1)]));
    asm volatile("vslide1down.vx v8, v10, %0" ::"r"(*i_slide_ptr_2++));
    asm volatile("vmacc.vx v22, %0, v14" ::"r"(f[0 + (2 * k + 1)]));
    asm volatile("vmacc.vx v16, %0, v14" ::"r"(f[21 + (2 * k + 1)]));
    asm volatile("vslide1down.vx v12, v14, %0" ::"r"(*i_slide_ptr_3++));
    asm volatile("vmacc.vx v20, %0, v14" ::"r"(f[7 + (2 * k + 1)]));
  }

  // Start calculating the next pointers to the elements to be slided in
  i_slide_ptr_0 = i + n_ + 0 * (C + F_arg - 1);
  i_slide_ptr_1 = i + n_ + 1 * (C + F_arg - 1);
  i_slide_ptr_2 = i + n_ + 2 * (C + F_arg - 1);

  // Main kernel, last iteration with filter coefficients reuse
  // Start loading next rows, from 4 to 6
  asm volatile("vmacc.vx v16, %0, v0" ::"r"(t6));
  asm volatile("vle64.v v2, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));
  asm volatile("vmacc.vx v18, %0, v4" ::"r"(t6));
  asm volatile("vmacc.vx v22, %0, v12" ::"r"(t6));
  asm volatile("vmacc.vx v16, %0, v4" ::"r"(t13));
  asm volatile("vle64.v v6, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));
  asm volatile("vmacc.vx v18, %0, v8" ::"r"(t13));
  asm volatile("vmacc.vx v20, %0, v8" ::"r"(t6));
  asm volatile("vmacc.vx v16, %0, v8" ::"r"(t20));
  asm volatile("vle64.v v10, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));
  asm volatile("vmacc.vx v18, %0, v12" ::"r"(t20));
  asm volatile("vmacc.vx v20, %0, v12" ::"r"(t13));
  asm volatile("vmacc.vx v16, %0, v12" ::"r"(t27));

  ////////////////
  // Row 4 -> 6 //
  ////////////////

  // Main kernel, unrolled by 2
  for (int k = 0; k < F_arg / 2; ++k) {
    asm volatile("vmacc.vx v16, %0, v2" ::"r"(f[28 + (2 * k)]));
    asm volatile("vmacc.vx v18, %0, v2" ::"r"(f[21 + (2 * k)]));
    asm volatile("vmacc.vx v16, %0, v6" ::"r"(f[35 + (2 * k)]));
    asm volatile("vmacc.vx v18, %0, v6" ::"r"(f[28 + (2 * k)]));
    asm volatile("vmacc.vx v16, %0, v10" ::"r"(f[42 + (2 * k)]));
    asm volatile("vslide1down.vx v0, v2, %0" ::"r"(*i_slide_ptr_0++));

    asm volatile("vmacc.vx v18, %0, v10" ::"r"(f[35 + (2 * k)]));
    asm volatile("vslide1down.vx v4, v6, %0" ::"r"(*i_slide_ptr_1++));

    asm volatile("vmacc.vx v20, %0, v2" ::"r"(f[14 + (2 * k)]));
    asm volatile("vmacc.vx v20, %0, v6" ::"r"(f[21 + (2 * k)]));
    asm volatile("vmacc.vx v20, %0, v10" ::"r"(f[28 + (2 * k)]));
    asm volatile("vslide1down.vx v8, v10, %0" ::"r"(*i_slide_ptr_2++));

    asm volatile("vmacc.vx v22, %0, v2" ::"r"(f[7 + (2 * k)]));
    asm volatile("vmacc.vx v22, %0, v6" ::"r"(f[14 + (2 * k)]));
    asm volatile("vmacc.vx v22, %0, v10" ::"r"(f[21 + (2 * k)]));

    if (k == 0)
      asm volatile("vmul.vx v24, v2, %0" ::"r"(f[0 + (2 * k)]));
    else
      asm volatile("vmacc.vx v24, %0, v2" ::"r"(f[0 + (2 * k)]));
    asm volatile("vmacc.vx v24, %0, v6" ::"r"(f[7 + (2 * k)]));
    asm volatile("vmacc.vx v24, %0, v10" ::"r"(f[14 + (2 * k)]));

    if (k == 0)
      asm volatile("vmul.vx v26, v6, %0" ::"r"(f[0 + (2 * k)]));
    else
      asm volatile("vmacc.vx v26, %0, v6" ::"r"(f[0 + (2 * k)]));
    asm volatile("vmacc.vx v26, %0, v10" ::"r"(f[7 + (2 * k)]));

    if (k == 0)
      asm volatile("vmul.vx v28, v10, %0" ::"r"(f[0 + (2 * k)]));
    else
      asm volatile("vmacc.vx v28, %0, v10" ::"r"(f[0 + (2 * k)]));

    asm volatile("vmacc.vx v16, %0, v0" ::"r"(f[28 + (2 * k + 1)]));
    asm volatile("vmacc.vx v16, %0, v4" ::"r"(f[35 + (2 * k + 1)]));
    asm volatile("vmacc.vx v16, %0, v8" ::"r"(f[42 + (2 * k + 1)]));
    asm volatile("vslide1down.vx v2, v0, %0" ::"r"(*i_slide_ptr_0++));

    asm volatile("vmacc.vx v18, %0, v0" ::"r"(f[21 + (2 * k + 1)]));
    asm volatile("vmacc.vx v18, %0, v4" ::"r"(f[28 + (2 * k + 1)]));
    asm volatile("vmacc.vx v18, %0, v8" ::"r"(f[35 + (2 * k + 1)]));
    asm volatile("vslide1down.vx v6, v4, %0" ::"r"(*i_slide_ptr_1++));

    asm volatile("vmacc.vx v20, %0, v0" ::"r"(f[14 + (2 * k + 1)]));
    asm volatile("vmacc.vx v20, %0, v4" ::"r"(f[21 + (2 * k + 1)]));
    asm volatile("vmacc.vx v20, %0, v8" ::"r"(f[28 + (2 * k + 1)]));
    asm volatile("vslide1down.vx v10, v8, %0" ::"r"(*i_slide_ptr_2++));

    asm volatile("vmacc.vx v22, %0, v0" ::"r"(f[7 + (2 * k + 1)]));
    asm volatile("vmacc.vx v22, %0, v4" ::"r"(f[14 + (2 * k + 1)]));
    asm volatile("vmacc.vx v22, %0, v8" ::"r"(f[21 + (2 * k + 1)]));

    asm volatile("vmacc.vx v24, %0, v0" ::"r"(f[0 + (2 * k + 1)]));
    asm volatile("vmacc.vx v24, %0, v4" ::"r"(f[7 + (2 * k + 1)]));
    asm volatile("vmacc.vx v24, %0, v8" ::"r"(f[14 + (2 * k + 1)]));

    asm volatile("vmacc.vx v26, %0, v4" ::"r"(f[0 + (2 * k + 1)]));
    asm volatile("vmacc.vx v26, %0, v8" ::"r"(f[7 + (2 * k + 1)]));

    asm volatile("vmacc.vx v28, %0, v8" ::"r"(f[0 + (2 * k + 1)]));
  }

  // Main kernel, last iteration with filter coefficients reuse
  asm volatile("vmacc.vx v16, %0, v2" ::"r"(t34));
  asm volatile("vmacc.vx v16, %0, v6" ::"r"(t41));
  asm volatile("vmacc.vx v16, %0, v10" ::"r"(t48));
  asm volatile("vse64.v v16, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));

  asm volatile("vmacc.vx v18, %0, v2" ::"r"(t27));
  asm volatile("vmacc.vx v18, %0, v6" ::"r"(t34));
  asm volatile("vmacc.vx v18, %0, v10" ::"r"(t41));
  asm volatile("vmv.v.v v16, v18");

  asm volatile("vmacc.vx v20, %0, v2" ::"r"(t20));
  asm volatile("vmacc.vx v20, %0, v6" ::"r"(t27));
  asm volatile("vmacc.vx v20, %0, v10" ::"r"(t34));
  asm volatile("vmv.v.v v18, v20");

  asm volatile("vmacc.vx v22, %0, v2" ::"r"(t13));
  asm volatile("vmacc.vx v22, %0, v6" ::"r"(t20));
  asm volatile("vmacc.vx v22, %0, v10" ::"r"(t27));
  asm volatile("vmv.v.v v20, v22");

  asm volatile("vmacc.vx v24, %0, v2" ::"r"(t6));
  asm volatile("vmacc.vx v24, %0, v6" ::"r"(t13));
  asm volatile("vmacc.vx v24, %0, v10" ::"r"(t20));
  asm volatile("vmv.v.v v22, v24");

  asm volatile("vmacc.vx v26, %0, v6" ::"r"(t6));
  asm volatile("vmacc.vx v26, %0, v10" ::"r"(t13));
  asm volatile("vmv.v.v v24, v26");

  asm volatile("vmacc.vx v28, %0, v10" ::"r"(t6));
  asm volatile("vmv.v.v v26, v28");

  ////////////
  // REGIME //
  ////////////

  // Start calculating the next pointers to the elements to be slided in
  i_slide_ptr_0 = i + n_;

  asm volatile("vle64.v v0, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));

  // The following loop is unrolled by 2
  // The input matrix has R + F - 1 rows
  // We have computed F input rows already
  // Compute now until only F input rows are left
  // (The last F-1 rows do not contribute to F output rows each, so keep them
  // outside of this loop) (We keep F rows outside because of the unrolling by
  // 2, just for easeness)
  for (int j = 0; j < ((R + F_arg - 1) - 2 * F_arg) / 2; ++j) {
    // Work on F output rows

    //////////////
    // UNROLL 0 //
    //////////////

    // Main loop
    for (int k = 0; k < F_arg / 2; ++k) {
      // Calculate F contributions of the input rows, on F different output rows
      asm volatile("vmacc.vx v16, %0, v0" ::"r"(f[42 + (2 * k)]));
      asm volatile("vmacc.vx v18, %0, v0" ::"r"(f[35 + (2 * k)]));
      asm volatile("vmacc.vx v20, %0, v0" ::"r"(f[28 + (2 * k)]));
      asm volatile("vslide1down.vx v2, v0, %0" ::"r"(*i_slide_ptr_0++));
      asm volatile("vmacc.vx v22, %0, v0" ::"r"(f[21 + (2 * k)]));
      asm volatile("vmacc.vx v24, %0, v0" ::"r"(f[14 + (2 * k)]));
      asm volatile("vmacc.vx v26, %0, v0" ::"r"(f[7 + (2 * k)]));
      if (k == 0)
        asm volatile("vmul.vx v28, v0, %0" ::"r"(f[0 + (2 * k)]));
      else
        asm volatile("vmacc.vx v28, %0, v0" ::"r"(f[0 + (2 * k)]));

      // Calculate F contributions of the input rows, on F different output rows
      asm volatile("vmacc.vx v16, %0, v2" ::"r"(f[42 + (2 * k + 1)]));
      asm volatile("vmacc.vx v18, %0, v2" ::"r"(f[35 + (2 * k + 1)]));
      asm volatile("vmacc.vx v20, %0, v2" ::"r"(f[28 + (2 * k + 1)]));
      asm volatile("vslide1down.vx v0, v2, %0" ::"r"(*i_slide_ptr_0++));
      asm volatile("vmacc.vx v22, %0, v2" ::"r"(f[21 + (2 * k + 1)]));
      asm volatile("vmacc.vx v24, %0, v2" ::"r"(f[14 + (2 * k + 1)]));
      asm volatile("vmacc.vx v26, %0, v2" ::"r"(f[7 + (2 * k + 1)]));
      asm volatile("vmacc.vx v28, %0, v2" ::"r"(f[0 + (2 * k + 1)]));
    }

    // Start calculating the next pointers to the elements to be slided in
    i_slide_ptr_1 = i + n_;

    // The last iteration is used to mask the latency of the store and the moves
    // Use buffered coefficients not to stall CVA6 for coherency
    asm volatile("vmacc.vx v16, %0, v0" ::"r"(t48));
    asm volatile("vse64.v  v16, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));
    asm volatile("vmacc.vx v18, %0, v0" ::"r"(t41));
    asm volatile("vmv.v.v v16, v18");
    asm volatile("vmacc.vx v20, %0, v0" ::"r"(t34));
    asm volatile("vle64.v v2, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));
    asm volatile("vmv.v.v v18, v20");
    asm volatile("vmacc.vx v22, %0, v0" ::"r"(t27));
    asm volatile("vmacc.vx v24, %0, v0" ::"r"(t20));
    asm volatile("vmv.v.v v20, v22");
    asm volatile("vmacc.vx v26, %0, v0" ::"r"(t13));
    asm volatile("vmacc.vx v28, %0, v0" ::"r"(t6));
    asm volatile("vmv.v.v v22, v24");

    //////////////
    // UNROLL 1 //
    //////////////

    asm volatile("vmacc.vx v16, %0, v2" ::"r"(f[42]));
    asm volatile("vmacc.vx v18, %0, v2" ::"r"(f[35]));
    asm volatile("vmv.v.v v24, v26");
    asm volatile("vmacc.vx v20, %0, v2" ::"r"(f[28]));
    asm volatile("vslide1down.vx v0, v2, %0" ::"r"(*i_slide_ptr_1++));
    asm volatile("vmacc.vx v22, %0, v2" ::"r"(f[21]));
    asm volatile("vmv.v.v v26, v28");
    asm volatile("vmacc.vx v24, %0, v2" ::"r"(f[14]));
    asm volatile("vmacc.vx v26, %0, v2" ::"r"(f[7]));
    asm volatile("vmul.vx v28, v2, %0" ::"r"(f[0]));

    for (int k = 1; k < F_arg; k += 2) {
      asm volatile("vmacc.vx v16, %0, v0" ::"r"(f[42 + k]));
      asm volatile("vmacc.vx v18, %0, v0" ::"r"(f[35 + k]));
      asm volatile("vmacc.vx v20, %0, v0" ::"r"(f[28 + k]));
      asm volatile("vslide1down.vx v2, v0, %0" ::"r"(*i_slide_ptr_1++));
      asm volatile("vmacc.vx v22, %0, v0" ::"r"(f[21 + k]));
      asm volatile("vmacc.vx v24, %0, v0" ::"r"(f[14 + k]));
      asm volatile("vmacc.vx v26, %0, v0" ::"r"(f[7 + k]));
      asm volatile("vmacc.vx v28, %0, v0" ::"r"(f[0 + k]));

      if (k == F_arg - 2)
        break;

      asm volatile("vmacc.vx v16, %0, v2" ::"r"(f[42 + (k + 1)]));
      asm volatile("vmacc.vx v18, %0, v2" ::"r"(f[35 + (k + 1)]));
      asm volatile("vmacc.vx v20, %0, v2" ::"r"(f[28 + (k + 1)]));
      asm volatile("vslide1down.vx v0, v2, %0" ::"r"(*i_slide_ptr_1++));
      asm volatile("vmacc.vx v22, %0, v2" ::"r"(f[21 + (k + 1)]));
      asm volatile("vmacc.vx v24, %0, v2" ::"r"(f[14 + (k + 1)]));
      asm volatile("vmacc.vx v26, %0, v2" ::"r"(f[7 + (k + 1)]));
      asm volatile("vmacc.vx v28, %0, v2" ::"r"(f[0 + (k + 1)]));
    }

    // Start calculating the next pointers to the elements to be slided in
    i_slide_ptr_0 = i + n_;

    asm volatile("vmacc.vx v16, %0, v2" ::"r"(t48));
    asm volatile("vse64.v  v16, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));
    asm volatile("vmacc.vx v18, %0, v2" ::"r"(t41));
    asm volatile("vmv.v.v v16, v18");
    asm volatile("vmacc.vx v20, %0, v2" ::"r"(t34));
    asm volatile("vle64.v v0, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));
    asm volatile("vmv.v.v v18, v20");
    asm volatile("vmacc.vx v22, %0, v2" ::"r"(t27));
    asm volatile("vmv.v.v v20, v22");
    asm volatile("vmacc.vx v24, %0, v2" ::"r"(t20));
    asm volatile("vmv.v.v v22, v24");
    asm volatile("vmacc.vx v26, %0, v2" ::"r"(t13));
    asm volatile("vmv.v.v v24, v26");
    asm volatile("vmacc.vx v28, %0, v2" ::"r"(t6));
    asm volatile("vmv.v.v v26, v28");
  }

  ////////////////////////
  // Row I-F -> (I-1)-3 //
  ////////////////////////

  // Point to the scalar elements to insert during a slide
  // i_slide_ptr_0 has already been computed
  i_slide_ptr_1 = i + n_ + 0 * (C + F_arg - 1);
  i_slide_ptr_2 = i + n_ + 1 * (C + F_arg - 1);
  i_slide_ptr_3 = i + n_ + 2 * (C + F_arg - 1);

  // Load other three input rows (one was already loaded)
  asm volatile("vle64.v v4, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));
  asm volatile("vle64.v v8, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));
  asm volatile("vle64.v v12, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));

  // Main kernel, unrolled by 2
  // Process 4 input rows
  for (int k = 0; k < F_arg / 2; ++k) {
    asm volatile("vslide1down.vx v2, v0, %0" ::"r"(*i_slide_ptr_0++));
    asm volatile("vmacc.vx v16, %0, v0" ::"r"(f[42 + (2 * k)]));
    asm volatile("vmacc.vx v18, %0, v0" ::"r"(f[35 + (2 * k)]));
    asm volatile("vmacc.vx v20, %0, v0" ::"r"(f[28 + (2 * k)]));
    asm volatile("vmacc.vx v22, %0, v0" ::"r"(f[21 + (2 * k)]));
    asm volatile("vmacc.vx v24, %0, v0" ::"r"(f[14 + (2 * k)]));
    asm volatile("vmacc.vx v26, %0, v0" ::"r"(f[7 + (2 * k)]));
    if (k == 0)
      asm volatile("vmul.vx v28, v0, %0" ::"r"(f[0 + (2 * k)]));
    else
      asm volatile("vmacc.vx v28, %0, v0" ::"r"(f[0 + (2 * k)]));
    asm volatile("vslide1down.vx v6, v4, %0" ::"r"(*i_slide_ptr_1++));
    asm volatile("vmacc.vx v18, %0, v4" ::"r"(f[42 + (2 * k)]));
    asm volatile("vmacc.vx v20, %0, v4" ::"r"(f[35 + (2 * k)]));
    asm volatile("vmacc.vx v22, %0, v4" ::"r"(f[28 + (2 * k)]));
    asm volatile("vmacc.vx v24, %0, v4" ::"r"(f[21 + (2 * k)]));
    asm volatile("vmacc.vx v26, %0, v4" ::"r"(f[14 + (2 * k)]));
    asm volatile("vmacc.vx v28, %0, v4" ::"r"(f[7 + (2 * k)]));
    asm volatile("vslide1down.vx v10, v8, %0" ::"r"(*i_slide_ptr_2++));
    asm volatile("vmacc.vx v20, %0, v8" ::"r"(f[42 + (2 * k)]));
    asm volatile("vmacc.vx v22, %0, v8" ::"r"(f[35 + (2 * k)]));
    asm volatile("vmacc.vx v24, %0, v8" ::"r"(f[28 + (2 * k)]));
    asm volatile("vmacc.vx v26, %0, v8" ::"r"(f[21 + (2 * k)]));
    asm volatile("vmacc.vx v28, %0, v8" ::"r"(f[14 + (2 * k)]));
    asm volatile("vslide1down.vx v14, v12, %0" ::"r"(*i_slide_ptr_3++));
    asm volatile("vmacc.vx v22, %0, v12" ::"r"(f[42 + (2 * k)]));
    asm volatile("vmacc.vx v24, %0, v12" ::"r"(f[35 + (2 * k)]));
    asm volatile("vmacc.vx v26, %0, v12" ::"r"(f[28 + (2 * k)]));
    asm volatile("vmacc.vx v28, %0, v12" ::"r"(f[21 + (2 * k)]));

    asm volatile("vslide1down.vx v0, v2, %0" ::"r"(*i_slide_ptr_0++));
    asm volatile("vmacc.vx v16, %0, v2" ::"r"(f[42 + (2 * k + 1)]));
    asm volatile("vmacc.vx v18, %0, v2" ::"r"(f[35 + (2 * k + 1)]));
    asm volatile("vmacc.vx v20, %0, v2" ::"r"(f[28 + (2 * k + 1)]));
    asm volatile("vmacc.vx v22, %0, v2" ::"r"(f[21 + (2 * k + 1)]));
    asm volatile("vmacc.vx v24, %0, v2" ::"r"(f[14 + (2 * k + 1)]));
    asm volatile("vmacc.vx v26, %0, v2" ::"r"(f[7 + (2 * k + 1)]));
    asm volatile("vmacc.vx v28, %0, v2" ::"r"(f[0 + (2 * k + 1)]));
    asm volatile("vslide1down.vx v4, v6, %0" ::"r"(*i_slide_ptr_1++));
    asm volatile("vmacc.vx v18, %0, v6" ::"r"(f[42 + (2 * k + 1)]));
    asm volatile("vmacc.vx v20, %0, v6" ::"r"(f[35 + (2 * k + 1)]));
    asm volatile("vmacc.vx v22, %0, v6" ::"r"(f[28 + (2 * k + 1)]));
    asm volatile("vmacc.vx v24, %0, v6" ::"r"(f[21 + (2 * k + 1)]));
    asm volatile("vmacc.vx v26, %0, v6" ::"r"(f[14 + (2 * k + 1)]));
    asm volatile("vmacc.vx v28, %0, v6" ::"r"(f[7 + (2 * k + 1)]));
    asm volatile("vslide1down.vx v8, v10, %0" ::"r"(*i_slide_ptr_2++));
    asm volatile("vmacc.vx v20, %0, v10" ::"r"(f[42 + (2 * k + 1)]));
    asm volatile("vmacc.vx v22, %0, v10" ::"r"(f[35 + (2 * k + 1)]));
    asm volatile("vmacc.vx v24, %0, v10" ::"r"(f[28 + (2 * k + 1)]));
    asm volatile("vmacc.vx v26, %0, v10" ::"r"(f[21 + (2 * k + 1)]));
    asm volatile("vmacc.vx v28, %0, v10" ::"r"(f[14 + (2 * k + 1)]));
    asm volatile("vslide1down.vx v12, v14, %0" ::"r"(*i_slide_ptr_3++));
    asm volatile("vmacc.vx v22, %0, v14" ::"r"(f[42 + (2 * k + 1)]));
    asm volatile("vmacc.vx v24, %0, v14" ::"r"(f[35 + (2 * k + 1)]));
    asm volatile("vmacc.vx v26, %0, v14" ::"r"(f[28 + (2 * k + 1)]));
    asm volatile("vmacc.vx v28, %0, v14" ::"r"(f[21 + (2 * k + 1)]));
  }

  // Start calculating the next pointers to the elements to be slided in
  i_slide_ptr_0 = i + n_ + 0 * (C + F_arg - 1);
  i_slide_ptr_1 = i + n_ + 1 * (C + F_arg - 1);
  i_slide_ptr_2 = i + n_ + 2 * (C + F_arg - 1);

  asm volatile("vle64.v v2, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));
  asm volatile("vmacc.vx v16, %0, v0" ::"r"(t48));
  asm volatile("vmacc.vx v18, %0, v0" ::"r"(t41));
  asm volatile("vmacc.vx v20, %0, v0" ::"r"(t34));
  asm volatile("vse64.v  v16, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));
  asm volatile("vmacc.vx v22, %0, v0" ::"r"(t27));
  asm volatile("vmacc.vx v24, %0, v0" ::"r"(t20));
  asm volatile("vmacc.vx v26, %0, v0" ::"r"(t13));
  asm volatile("vle64.v v6, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));
  asm volatile("vmacc.vx v28, %0, v0" ::"r"(t6));
  asm volatile("vmacc.vx v18, %0, v4" ::"r"(t48));
  asm volatile("vmacc.vx v20, %0, v4" ::"r"(t41));
  asm volatile("vse64.v  v18, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));
  asm volatile("vmacc.vx v22, %0, v4" ::"r"(t34));
  asm volatile("vmacc.vx v24, %0, v4" ::"r"(t27));
  asm volatile("vmacc.vx v26, %0, v4" ::"r"(t20));
  asm volatile("vle64.v v10, (%0); add %0, %0, %1" : "+&r"(i) : "r"(ldi_pad));
  asm volatile("vmacc.vx v28, %0, v4" ::"r"(t13));
  asm volatile("vmacc.vx v20, %0, v8" ::"r"(t48));
  asm volatile("vmacc.vx v22, %0, v8" ::"r"(t41));
  asm volatile("vse64.v  v20, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));
  asm volatile("vmacc.vx v24, %0, v8" ::"r"(t34));
  asm volatile("vmacc.vx v26, %0, v8" ::"r"(t27));
  asm volatile("vmacc.vx v28, %0, v8" ::"r"(t20));
  asm volatile("vmacc.vx v22, %0, v12" ::"r"(t48));
  asm volatile("vse64.v  v22, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));
  asm volatile("vmacc.vx v24, %0, v12" ::"r"(t41));
  asm volatile("vmacc.vx v26, %0, v12" ::"r"(t34));
  asm volatile("vmacc.vx v28, %0, v12" ::"r"(t27));

  //////////////////////////
  // Row (I-1)-3 -> (I-1) //
  //////////////////////////

  // Main kernel, unrolled by 2
  for (int k = 0; k < F_arg / 2; ++k) {
    asm volatile("vslide1down.vx v0, v2, %0" ::"r"(*i_slide_ptr_0++));
    asm volatile("vmacc.vx v24, %0, v2" ::"r"(f[42 + (2 * k)]));
    asm volatile("vmacc.vx v26, %0, v2" ::"r"(f[35 + (2 * k)]));
    asm volatile("vslide1down.vx v4, v6, %0" ::"r"(*i_slide_ptr_1++));
    asm volatile("vmacc.vx v28, %0, v2" ::"r"(f[28 + (2 * k)]));
    asm volatile("vmacc.vx v26, %0, v6" ::"r"(f[42 + (2 * k)]));
    asm volatile("vslide1down.vx v8, v10, %0" ::"r"(*i_slide_ptr_2++));
    asm volatile("vmacc.vx v28, %0, v6" ::"r"(f[35 + (2 * k)]));
    asm volatile("vmacc.vx v28, %0, v10" ::"r"(f[42 + (2 * k)]));

    asm volatile("vslide1down.vx v2, v0, %0" ::"r"(*i_slide_ptr_0++));
    asm volatile("vmacc.vx v24, %0, v0" ::"r"(f[42 + (2 * k + 1)]));
    asm volatile("vmacc.vx v26, %0, v0" ::"r"(f[35 + (2 * k + 1)]));
    asm volatile("vslide1down.vx v6, v4, %0" ::"r"(*i_slide_ptr_1++));
    asm volatile("vmacc.vx v28, %0, v0" ::"r"(f[28 + (2 * k + 1)]));
    asm volatile("vmacc.vx v26, %0, v4" ::"r"(f[42 + (2 * k + 1)]));
    asm volatile("vslide1down.vx v10, v8, %0" ::"r"(*i_slide_ptr_2++));
    asm volatile("vmacc.vx v28, %0, v4" ::"r"(f[35 + (2 * k + 1)]));
    asm volatile("vmacc.vx v28, %0, v8" ::"r"(f[42 + (2 * k + 1)]));
  }

  asm volatile("vmacc.vx v24, %0, v2" ::"r"(t48));
  asm volatile("vse64.v  v24, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));
  asm volatile("vmacc.vx v26, %0, v2" ::"r"(t41));
  asm volatile("vmacc.vx v28, %0, v2" ::"r"(t34));
  asm volatile("vmacc.vx v26, %0, v6" ::"r"(t48));
  asm volatile("vse64.v  v26, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));
  asm volatile("vmacc.vx v28, %0, v6" ::"r"(t41));
  asm volatile("vmacc.vx v28, %0, v10" ::"r"(t48));
  asm volatile("vse64.v  v28, (%0); add %0, %0, %1" : "+&r"(o) : "r"(ldo));
}

void iconv2d_7x7(int64_t *o, int64_t *i, int64_t *f, int64_t M_arg, int64_t N_arg, int64_t F_arg) {

  unsigned long int block_size_n;

  // Set the vector configuration
  asm volatile("vsetvli %0, %1, e64, m2, ta, ma" : "=r"(block_size_n) : "r"(N_arg));

  // Slice the matrix into a manageable number of columns n_
  for (unsigned long int n = 0; n < N_arg; n += block_size_n) {
    // Set the vector length
    const unsigned long int n_ = MIN(N_arg - n, block_size_n);

    // Find pointers to the submatrices
    const int64_t *i_ = i + n;
    int64_t *o_ = o + n;

    asm volatile("vsetvli zero, %0, e64, m2, ta, ma" ::"r"(n_));

    iconv2d_7x7_block(o_, i_, f, M_arg, N_arg, n_, F_arg);
  }
}

// ======================================================
// ICONV2D MAIN DISPATCH
// ======================================================

void iconv2d(
    int64_t *o,
    int64_t i[MAX_CHANNELS][MAX_INPUT_ROWS * MAX_INPUT_COLS],
    int64_t f[MAX_CHANNELS][MAX_F * MAX_F],
    int64_t R, 
    int64_t C, 
    int64_t F_arg, 
    int64_t channels)
{

    // Clear final output
    clear_matrix(o, R, C);

    for (int ch = 0; ch < channels; ch++)
    {
        // Temporary output for this channel
        clear_matrix(temp_o, R, C);

        if (F_arg == 3)
            iconv2d_3x3(temp_o, i[ch], f[ch], R, C, F_arg);

        else if (F_arg == 5)
            iconv2d_5x5(temp_o, i[ch], f[ch], R, C, F_arg);

        else if (F_arg == 7)
            iconv2d_7x7(temp_o, i[ch], f[ch], R, C, F_arg);

        // Accumulate into final output
        add_matrix(o, temp_o, R, C);
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
    
    int result_idx = 0;
    
    // Build test list
    test_config_t tests[16];

    // F = 3 and M = 256
    tests[0] = (test_config_t){3, 256, 1};
    tests[1] = (test_config_t){3, 256, 3};
    tests[2] = (test_config_t){3, 256, 8};
    tests[3] = (test_config_t){3, 256, 16};

    int num_tests = 4;

    // Run tests
    for (int t = 0; t < num_tests; t++) {
        
        // Benchmark config
        test_config_t cfg = tests[t];

        int F = cfg.filter_size;

        int M = cfg.matrix_size;
        int N = cfg.matrix_size;

        int PAD = F / 2;

        int INPUT_ROWS = M + 2 * PAD;
        int INPUT_COLS = N + 2 * PAD;

        int channels = cfg.channels;

        // Generate deterministic data 
        for (int ch = 0; ch < channels; ch++)
        {
            fill_matrix(i[ch], INPUT_ROWS, INPUT_COLS);
            fill_matrix(f[ch], F, F);
        }

        // Golden reference
        clear_matrix(golden_o, M, N);
        iconv2d_scalar(golden_o, i, f, M, N, F, INPUT_COLS, channels);

        // Print only one once per test
        results[result_idx++] = cfg.filter_size;
        results[result_idx++] = cfg.channels;

        for (int iter = 0; iter < 10; iter++) {

            // Run benchmark
            uint64_t start = get_cycle_count();
            iconv2d(o, i, f, M, N, F, channels);
            uint64_t end = get_cycle_count();

            // Verification
            int verify = verify_matrix(o, golden_o, M, N);

            // Store results
            results[result_idx++] = end - start;
            results[result_idx++] = verify;
        }
    }

    // Keep CPU alive on FPGA
    while (1);

    return 0;
}
