package toy_conv1_meta;

  // Geometry
  parameter int TOY_IN_H   = 5;
  parameter int TOY_IN_W   = 5;
  parameter int TOY_IN_C   = 1;
  parameter int TOY_KH     = 3;
  parameter int TOY_KW     = 3;
  parameter int TOY_STRIDE = 1;
  parameter int TOY_PAD    = 1;

  parameter int TOY_OUT_H  = 5;
  parameter int TOY_OUT_W  = 5;
  parameter int TOY_OUT_C  = 4;

  parameter int TOY_M      = TOY_OUT_H * TOY_OUT_W; // 25
  parameter int TOY_K      = TOY_IN_C * TOY_KH * TOY_KW; // 9
  parameter int TOY_COUT   = TOY_OUT_C; // 4

  // File paths (relative to BG_PROJECT)
  parameter string TOY_INPUT_CSV   = "toy_toplitz/layers/001_conv1/input.csv";
  parameter string TOY_TOPLITZ_CSV = "toy_toplitz/layers/001_conv1/toplitz.csv";
  parameter string TOY_WEIGHTS_CSV = "toy_toplitz/layers/001_conv1/weights.csv";
  parameter string TOY_GOLDEN_CSV  = "toy_toplitz/layers/001_conv1/golden_output.csv";

endpackage
