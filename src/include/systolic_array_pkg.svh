`ifndef SYSTOLIC_ARRAY_PKG_SVH
`define SYSTOLIC_ARRAY_PKG_SVH

localparam WORD_SIZE = 32;

typedef logic [WORD_SIZE-1:0] word_t;
// typedef struct packed {
//     logic sign;
//     logic [7:0] exponent;
//     logic [22:0] mantissa;
// } word_t;

`endif // SYSTOLIC_ARRAY_PKG_SVH