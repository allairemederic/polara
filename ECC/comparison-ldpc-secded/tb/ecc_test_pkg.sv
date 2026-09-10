package ecc_test_pkg;

    typedef enum {
        RECOVERED,
        DETECTED_NOT_RECOVERED,
        UNDETECTED
    } ecc_result_t;

    function automatic logic [143:0] single_bit_mask(
        input int bit_position
    );
        logic [143:0] mask;
        mask = '0;
        mask[bit_position] = 1'b1;
        return mask;
    endfunction

endpackage