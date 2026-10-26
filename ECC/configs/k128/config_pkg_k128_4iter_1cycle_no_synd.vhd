-------------------------------------------------------------------------------
--! @file       config_pkg.vhd
--! @brief      Template for the config package file. Generate the package by executing the "configPackage.py" python script. 
--! @author     Jeremy Nadal <jeremy.nadal@polymtl.ca>
-- Project    : Modified Gallager B decoder
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Copyright (c) 2022
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

package config_pkg is

  -- Unconstrained array type.
  type T_UARRAY_INT is array(integer range <>) of integer;
  type T_2D_UARRAY_INT is array(integer range <>, integer range<>) of integer;
  type T_PIP_CFG is array (0 to 1) of boolean;

  -- CONSTANTS, pulled from config file
  -- DO NOT EDIT MANUALLY as they will be overwritten

  -- Code name.
  constant PKG_CODE_NAME : string := "H_k128";

  constant PKG_PROJECT_HOME : string := "";
  constant PKG_SIM_DIR : string := "";
  constant PKG_SYN_DIR : string := "";

  -- Code parameters.
  constant PKG_NUM_PAR_BITS   : natural := 16;
  constant PKG_NUM_SYS_BITS   : natural := 128;
  constant PKG_NUM_G_SYS_BITS : natural := 128;
  constant PKG_NUM_ITERATIONS : natural := 4;
  constant PKG_CODE_LENGTH    : natural := PKG_NUM_PAR_BITS+PKG_NUM_SYS_BITS;
  constant PKG_NUM_EDGES      : natural := 552;

  -- Tanner graph config.
  constant PKG_CND_LIST          : T_UARRAY_INT(0 to PKG_NUM_PAR_BITS-1)                              := (35, 35, 35, 35, 34, 34, 34, 34, 35, 35, 35, 35, 34, 34, 34, 34);
  constant PKG_VND_LIST          : T_UARRAY_INT(0 to PKG_CODE_LENGTH-1)                               := (4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1, 1, 1, 1, 4, 4, 4, 4, 1, 1, 1, 1);
  constant PKG_VN_THRESHOLD_LIST : T_2D_UARRAY_INT(0 to PKG_NUM_ITERATIONS-1, 0 to PKG_CODE_LENGTH-1) := ((3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 1, 1, 1, 1, 3, 3, 3, 3, 1, 1, 1, 1), (3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 1, 1, 1, 1, 3, 3, 3, 3, 1, 1, 1, 1), (3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 1, 1, 1, 1, 3, 3, 3, 3, 1, 1, 1, 1), (4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1, 1, 1, 1, 4, 4, 4, 4, 1, 1, 1, 1));
  constant PKG_CN2VN_EDGE_MAP    : T_UARRAY_INT(0 to PKG_NUM_EDGES-1)                                 := (0, 35, 70, 140, 1, 36, 105, 141, 2, 71, 106, 142, 3, 37, 72, 174, 4, 38, 107, 175, 5, 73, 108, 176, 6, 39, 143, 177, 7, 74, 144, 178, 40, 75, 145, 179, 8, 109, 146, 180, 41, 110, 147, 181, 76, 111, 148, 182, 9, 42, 77, 208, 10, 43, 112, 209, 11, 78, 113, 210, 12, 44, 149, 211, 13, 79, 150, 212, 45, 80, 151, 213, 14, 114, 152, 214, 46, 115, 153, 215, 81, 116, 154, 216, 15, 47, 183, 217, 16, 82, 184, 218, 48, 83, 185, 219, 17, 117, 186, 220, 49, 118, 187, 221, 84, 119, 188, 222, 18, 155, 189, 223, 50, 156, 190, 224, 85, 157, 191, 225, 120, 158, 192, 226, 19, 51, 86, 242, 20, 52, 121, 243, 53, 87, 122, 244, 21, 54, 159, 245, 22, 88, 160, 246, 55, 89, 161, 247, 23, 123, 162, 248, 56, 124, 163, 249, 90, 125, 164, 250, 24, 57, 193, 251, 25, 91, 194, 252, 58, 92, 195, 253, 26, 126, 196, 254, 59, 127, 197, 255, 93, 128, 198, 256, 27, 165, 199, 257, 60, 166, 200, 258, 94, 167, 201, 259, 129, 168, 202, 260, 28, 61, 227, 261, 29, 95, 228, 262, 62, 96, 229, 263, 30, 130, 230, 264, 63, 131, 231, 265, 97, 132, 232, 266, 31, 169, 233, 267, 64, 170, 234, 268, 98, 171, 235, 269, 133, 172, 236, 270, 32, 203, 237, 271, 65, 204, 238, 272, 99, 205, 239, 273, 134, 206, 240, 274, 276, 311, 346, 416, 277, 312, 381, 417, 278, 347, 382, 418, 279, 313, 348, 450, 280, 314, 383, 451, 281, 349, 384, 452, 282, 315, 419, 453, 283, 350, 420, 454, 316, 351, 421, 455, 284, 385, 422, 456, 317, 386, 423, 457, 352, 387, 424, 458, 285, 318, 353, 484, 286, 319, 388, 485, 287, 354, 389, 486, 288, 320, 425, 487, 289, 355, 426, 488, 321, 356, 427, 489, 290, 390, 428, 490, 322, 391, 429, 491, 357, 392, 430, 492, 291, 323, 459, 493, 292, 358, 460, 494, 324, 359, 461, 495, 293, 393, 462, 496, 325, 394, 463, 497, 360, 395, 464, 498, 294, 431, 465, 499, 326, 432, 466, 500, 361, 433, 467, 501, 396, 434, 468, 502, 295, 327, 362, 518, 296, 328, 397, 519, 329, 363, 398, 520, 297, 330, 435, 521, 298, 364, 436, 522, 331, 365, 437, 523, 299, 399, 438, 524, 332, 400, 439, 525, 366, 401, 440, 526, 300, 333, 469, 527, 301, 367, 470, 528, 334, 368, 471, 529, 302, 402, 472, 530, 335, 403, 473, 531, 369, 404, 474, 532, 303, 441, 475, 533, 336, 442, 476, 534, 370, 443, 477, 535, 405, 444, 478, 536, 304, 337, 503, 537, 305, 371, 504, 538, 338, 372, 505, 539, 306, 406, 506, 540, 339, 407, 507, 541, 373, 408, 508, 542, 307, 445, 509, 543, 340, 446, 510, 544, 374, 447, 511, 545, 409, 448, 512, 546, 308, 479, 513, 547, 341, 480, 514, 548, 375, 481, 515, 549, 410, 482, 516, 550, 66, 100, 135, 173, 67, 101, 136, 207, 68, 102, 137, 241, 33, 103, 138, 275, 34, 69, 104, 139, 342, 376, 411, 449, 343, 377, 412, 483, 344, 378, 413, 517, 309, 379, 414, 551, 310, 345, 380, 415);
  constant PKG_VN2CN_EDGE_MAP    : T_UARRAY_INT(0 to PKG_NUM_EDGES-1)                                 := (0, 4, 8, 12, 16, 20, 24, 28, 36, 48, 52, 56, 60, 64, 72, 84, 88, 96, 108, 124, 128, 136, 140, 148, 160, 164, 172, 184, 200, 204, 212, 224, 240, 524, 528, 1, 5, 13, 17, 25, 32, 40, 49, 53, 61, 68, 76, 85, 92, 100, 112, 125, 129, 132, 137, 144, 152, 161, 168, 176, 188, 201, 208, 216, 228, 244, 512, 516, 520, 529, 2, 9, 14, 21, 29, 33, 44, 50, 57, 65, 69, 80, 89, 93, 104, 116, 126, 133, 141, 145, 156, 165, 169, 180, 192, 205, 209, 220, 232, 248, 513, 517, 521, 525, 530, 6, 10, 18, 22, 37, 41, 45, 54, 58, 73, 77, 81, 97, 101, 105, 120, 130, 134, 149, 153, 157, 173, 177, 181, 196, 213, 217, 221, 236, 252, 514, 518, 522, 526, 531, 3, 7, 11, 26, 30, 34, 38, 42, 46, 62, 66, 70, 74, 78, 82, 109, 113, 117, 121, 138, 142, 146, 150, 154, 158, 185, 189, 193, 197, 225, 229, 233, 237, 515, 15, 19, 23, 27, 31, 35, 39, 43, 47, 86, 90, 94, 98, 102, 106, 110, 114, 118, 122, 162, 166, 170, 174, 178, 182, 186, 190, 194, 198, 241, 245, 249, 253, 519, 51, 55, 59, 63, 67, 71, 75, 79, 83, 87, 91, 95, 99, 103, 107, 111, 115, 119, 123, 202, 206, 210, 214, 218, 222, 226, 230, 234, 238, 242, 246, 250, 254, 523, 127, 131, 135, 139, 143, 147, 151, 155, 159, 163, 167, 171, 175, 179, 183, 187, 191, 195, 199, 203, 207, 211, 215, 219, 223, 227, 231, 235, 239, 243, 247, 251, 255, 527, 256, 260, 264, 268, 272, 276, 280, 284, 292, 304, 308, 312, 316, 320, 328, 340, 344, 352, 364, 380, 384, 392, 396, 404, 416, 420, 428, 440, 456, 460, 468, 480, 496, 544, 548, 257, 261, 269, 273, 281, 288, 296, 305, 309, 317, 324, 332, 341, 348, 356, 368, 381, 385, 388, 393, 400, 408, 417, 424, 432, 444, 457, 464, 472, 484, 500, 532, 536, 540, 549, 258, 265, 270, 277, 285, 289, 300, 306, 313, 321, 325, 336, 345, 349, 360, 372, 382, 389, 397, 401, 412, 421, 425, 436, 448, 461, 465, 476, 488, 504, 533, 537, 541, 545, 550, 262, 266, 274, 278, 293, 297, 301, 310, 314, 329, 333, 337, 353, 357, 361, 376, 386, 390, 405, 409, 413, 429, 433, 437, 452, 469, 473, 477, 492, 508, 534, 538, 542, 546, 551, 259, 263, 267, 282, 286, 290, 294, 298, 302, 318, 322, 326, 330, 334, 338, 365, 369, 373, 377, 394, 398, 402, 406, 410, 414, 441, 445, 449, 453, 481, 485, 489, 493, 535, 271, 275, 279, 283, 287, 291, 295, 299, 303, 342, 346, 350, 354, 358, 362, 366, 370, 374, 378, 418, 422, 426, 430, 434, 438, 442, 446, 450, 454, 497, 501, 505, 509, 539, 307, 311, 315, 319, 323, 327, 331, 335, 339, 343, 347, 351, 355, 359, 363, 367, 371, 375, 379, 458, 462, 466, 470, 474, 478, 482, 486, 490, 494, 498, 502, 506, 510, 543, 383, 387, 391, 395, 399, 403, 407, 411, 415, 419, 423, 427, 431, 435, 439, 443, 447, 451, 455, 459, 463, 467, 471, 475, 479, 483, 487, 491, 495, 499, 503, 507, 511, 547);
  constant PKG_CHANNEL_BITS_MAP  : T_UARRAY_INT(0 to PKG_NUM_EDGES-1)                                 := (0, 1, 2, 3, 4, 5, 6, 7, 9, 12, 13, 14, 15, 16, 18, 21, 22, 24, 27, 31, 32, 34, 35, 37, 40, 41, 43, 46, 50, 51, 53, 56, 60, 131, 132, 0, 1, 3, 4, 6, 8, 10, 12, 13, 15, 17, 19, 21, 23, 25, 28, 31, 32, 33, 34, 36, 38, 40, 42, 44, 47, 50, 52, 54, 57, 61, 128, 129, 130, 133, 0, 2, 3, 5, 7, 8, 11, 12, 14, 16, 17, 20, 22, 23, 26, 29, 31, 33, 35, 36, 39, 41, 42, 45, 48, 51, 52, 55, 58, 62, 128, 129, 130, 131, 134, 1, 2, 4, 5, 9, 10, 11, 13, 14, 18, 19, 20, 24, 25, 26, 30, 32, 33, 37, 38, 39, 43, 44, 45, 49, 53, 54, 55, 59, 63, 128, 129, 130, 131, 135, 0, 1, 2, 6, 7, 8, 9, 10, 11, 15, 16, 17, 18, 19, 20, 27, 28, 29, 30, 34, 35, 36, 37, 38, 39, 46, 47, 48, 49, 56, 57, 58, 59, 128, 3, 4, 5, 6, 7, 8, 9, 10, 11, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 60, 61, 62, 63, 129, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 130, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 131, 64, 65, 66, 67, 68, 69, 70, 71, 73, 76, 77, 78, 79, 80, 82, 85, 86, 88, 91, 95, 96, 98, 99, 101, 104, 105, 107, 110, 114, 115, 117, 120, 124, 139, 140, 64, 65, 67, 68, 70, 72, 74, 76, 77, 79, 81, 83, 85, 87, 89, 92, 95, 96, 97, 98, 100, 102, 104, 106, 108, 111, 114, 116, 118, 121, 125, 136, 137, 138, 141, 64, 66, 67, 69, 71, 72, 75, 76, 78, 80, 81, 84, 86, 87, 90, 93, 95, 97, 99, 100, 103, 105, 106, 109, 112, 115, 116, 119, 122, 126, 136, 137, 138, 139, 142, 65, 66, 68, 69, 73, 74, 75, 77, 78, 82, 83, 84, 88, 89, 90, 94, 96, 97, 101, 102, 103, 107, 108, 109, 113, 117, 118, 119, 123, 127, 136, 137, 138, 139, 143, 64, 65, 66, 70, 71, 72, 73, 74, 75, 79, 80, 81, 82, 83, 84, 91, 92, 93, 94, 98, 99, 100, 101, 102, 103, 110, 111, 112, 113, 120, 121, 122, 123, 136, 67, 68, 69, 70, 71, 72, 73, 74, 75, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 124, 125, 126, 127, 137, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 138, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 139);

  -- List of the iteration indexes where the flip rule is enabled.
  constant PKG_NUM_ITER_FLIP_RULE  : natural                                     := 1;
  constant PKG_FLIP_RULE_ITER_LIST : T_UARRAY_INT(0 to PKG_NUM_ITER_FLIP_RULE-1) := (0 => 3);
  constant PKG_VERSION             : natural                                     := 1;

  -- Pipeline configuration.
  -- -1 signifies an empty list
  constant PKG_NUM_INNER_PIP_STAGES : natural                                       := 1;
  constant PKG_NUM_OUTER_PIP_STAGES : natural                                       := 1;
  constant PKG_INNER_PIP_LIST       : T_UARRAY_INT(0 to PKG_NUM_INNER_PIP_STAGES-1) := (0 => -1);
  constant PKG_OUTER_PIP_LIST       : T_UARRAY_INT(0 to PKG_NUM_OUTER_PIP_STAGES-1) := (0 => 3);
  -- Replace pipeline with FIFO for info bits. Only works for V1 LA-GaB. Info
  -- bits are only used for the final decision.
  constant PKG_INFO_FIFO            : boolean                                       := True;
  -- Clock gate message pipeline  when the syndrome from initial iter in V1 is
  -- null
  constant PKG_NULL_SYNDROME_CG     : boolean                                       := False;


  -- Other hardware specific constants 
  constant PKG_CLOCK_PERIOD              : time      := 1000 ps;
  constant PKG_ASYNC_RESET_LOGIC         : std_logic := '1';
  constant PKG_ENABLE_TOP_INPUT_LATCHING : boolean   := True;

  -- Testbench constants
  constant PKG_TB_TV_P0                  : string := "6e-8";
  constant PKG_TB_TV_VERIF_PATH          : string := "/results/tv/H_k128/4/6e-8/";
  constant PKG_TB_TV_VERIF_MODULE_PATH   : string := PKG_PROJECT_HOME & "/results/tv/module_activity/";

  ----------------------------------------------------
  --           FUNCTION DECLARATIONS                --
  ----------------------------------------------------

  function PKG_IS_FLIP_RULE_ENABLED (
    iterIndex : natural
    ) return boolean;

  function PKG_GET_NUM_PIP_STAGES (
    iterIndex : natural
    ) return natural;

  function PKG_IS_INNER_PIPELINED (
    iterIndex : natural
    ) return boolean;

  function PKG_IS_OUTER_PIPELINED (
    iterIndex : natural
    ) return boolean;

  function PKG_CN_MAP (
    nodeIndex : natural
    ) return natural;

  function PKG_VN_MAP (
    nodeIndex : natural
    ) return natural;

end package config_pkg;

package body config_pkg is

  -- Return true if there is a pipeline register at the output of the VNU at iteration index "iterIndex".
  function PKG_EDGE_COUNT(nodeIndex : in natural; degreeList : in T_UARRAY_INT) return natural is
    variable V_cumul_index : natural;
  begin

    V_cumul_index := 0;

    if nodeIndex = 0 then
      return V_cumul_index;
    end if;

    for I in 0 to nodeIndex-1 loop
      V_cumul_index := V_cumul_index + degreeList(I);
    end loop;
    return V_cumul_index;

  end function;


  -- Return true if the flip rule is applied at the inputted iteration index.
  function PKG_IS_FLIP_RULE_ENABLED(iterIndex : in natural) return boolean is
  begin

    for I in PKG_FLIP_RULE_ITER_LIST'range loop
      if PKG_FLIP_RULE_ITER_LIST(I) = iterIndex then
        return true;
      end if;
    end loop;
    return false;

  end function;


  function PKG_GET_NUM_PIP_STAGES(iterIndex : in natural) return natural is
    variable INNER_PIPELINE : boolean := PKG_IS_INNER_PIPELINED(iterIndex);
    variable OUTER_PIPELINE : boolean := PKG_IS_OUTER_PIPELINED(iterIndex);
  begin

    if INNER_PIPELINE and OUTER_PIPELINE then
      return 2;
    end if;

    if INNER_PIPELINE or OUTER_PIPELINE then
      return 1;
    end if;

    return 0;

  end function;

  -- Return true if there is pipeline register between the CNU and VNU at iteration index "iterIndex".
  function PKG_IS_INNER_PIPELINED(iterIndex : in natural) return boolean is
  begin


    for I in PKG_INNER_PIP_LIST'range loop
      if PKG_INNER_PIP_LIST(I) = iterIndex then
        return true;
      end if;
    end loop;
    return false;

  end function;

  function PKG_IS_OUTER_PIPELINED(iterIndex : in natural) return boolean is
  begin

    for I in 0 to PKG_NUM_OUTER_PIP_STAGES-1 loop
      if PKG_OUTER_PIP_LIST(I) = iterIndex then
        return true;
      end if;
    end loop;
    return false;

  end function;

  function PKG_CN_MAP(nodeIndex : in natural) return natural is
  begin
    return PKG_EDGE_COUNT(nodeIndex, PKG_CND_LIST);
  end function;

  function PKG_VN_MAP(nodeIndex : in natural) return natural is
  begin
    return PKG_EDGE_COUNT(nodeIndex, PKG_VND_LIST);
  end function;



end package body config_pkg;
