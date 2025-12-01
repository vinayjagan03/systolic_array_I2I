package alexnet_conv1_meta;

  // ---- From metadata.json (conv1) ----
  parameter int CONV1_IM2COL_M      = 3136;  // out_h * out_w
  parameter int CONV1_IM2COL_K      = 363;   // depth of each im2col row
  parameter int CONV1_WEIGHTS_K     = 363;
  parameter int CONV1_WEIGHTS_COUT  = 96;

  parameter int CONV1_OUT_H         = 56;
  parameter int CONV1_OUT_W         = 56;
  parameter int CONV1_OUT_C         = 96;

  // systolic array tile size (from project spec)
  parameter int SA_N                = 64;

  // ---- File paths (relative to BG_PROJECT) ----
  parameter string CONV1_INPUT_CSV   = "alexnet_toplitz/layers/001_conv1/input.csv";
  parameter string CONV1_TOPLITZ_CSV = "alexnet_toplitz/layers/001_conv1/toplitz.csv";
  parameter string CONV1_WEIGHTS_CSV = "alexnet_toplitz/layers/001_conv1/weights.csv";
  parameter string CONV1_GOLDEN_CSV  = "alexnet_toplitz/layers/001_conv1/golden_output.csv";

  // TB output path
  parameter string CONV1_RTL_OUT_CSV = "alexnet_toplitz/layers/001_conv1/rtl_output.csv";

endpackage : alexnet_conv1_meta
