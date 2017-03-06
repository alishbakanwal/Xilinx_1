<<<<<<< HEAD
version https://git-lfs.github.com/spec/v1
oid sha256:10daf2df84d15a5f4c6c94b926943f0d6e842fe22f4f9183444d23607c677c24
size 259204
=======
------------------------------------------------------------------------------
-- "float_pkg" package contains functions for floating point math.
-- Please see the documentation for the floating point package.
-- This package should be compiled into "ieee_proposed" and used as follows:
-- use ieee.std_logic_1164.all;
-- use ieee.numeric_std.all;
-- use ieee_proposed.float_pkg.all;
-- Last Modified: $Date: 2006/05/09 19:21:24 $
-- RCS ID: $Id: float_pkg_c.vhd,v 1.1 2006/05/09 19:21:24 sandeepd Exp $
--
--  Created for VHDL-200X par, David Bishop (dbishop@vhdl.org)
------------------------------------------------------------------------------
library ieee, ieee_proposed;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee_proposed.fixed_pkg.all;
-- synthesis translate_off
use std.textio.all;
-- synthesis translate_on

package float_pkg is
  --%%% Uncomment the Generics
--  new work.fixed_generic_pkg
--  generic map (
--    float_exponent_width => 8;    -- float32'high
--    float_fraction_width => 23;   -- -float32'low
--    float_round_style    => round_nearest;  -- round nearest algorithm
--    float_denormalize    => true;  -- Use IEEE extended floating
--    float_check_error    => true;  -- Turn on NAN and overflow processing
--    float_guard_bits     => 3;     -- number of guard bits
--    no_warning           => false  -- show warnings
--    );
  --%%% REMOVE THE REST OF THIS FILE.
  constant float_exponent_width : NATURAL := 8;  -- float32'high
  constant float_fraction_width : NATURAL := 23;  -- -float32'low
  constant float_round_style : round_type := round_nearest;  -- round nearest algorithm
  constant float_denormalize : BOOLEAN    := true;  -- Use IEEE extended floating
                                        -- point (Denormalized numbers)
  constant float_check_error : BOOLEAN    := true;  -- Turn on NAN and overflow processing
  constant float_guard_bits  : NATURAL    := 3;     -- number of guard bits
  constant NO_WARNING        : BOOLEAN    := false;
  -- Author David Bishop (dbishop@vhdl.org)
  constant CopyRightNotice   : STRING     :=
    "Copyright 2005 by IEEE. All rights reserved.";
  -- Note that the size of the vector is not defined here, but in
  -- the package which calls this one.
  type    float is array (INTEGER range <>) of STD_LOGIC;       -- main type
  -----------------------------------------------------------------------------
  -- Use the float type to define your own floating point numbers.
  -- There must be a negative index or the packages will error out.
  -- Minimum supported is "subtype float7 is float (3 downto -3);"
  -- "subtype float16 is float (6 downto -9);" is probably the smallest
  -- practical one to use.
  -----------------------------------------------------------------------------
  subtype float32 is float (8 downto -23);     -- IEEE 754 single precision
  -----------------------------------------------------------------------------
  -- IEEE-754 single precision floating point.  This is a "float"
  -- in C, and a FLOAT in Fortran.  The exponent is 8 bits wide, and
  -- the fraction is 23 bits wide.  This format can hold roughly 7 decimal
  -- digits.  Infinity is 2**127 = 1.7E38 in this number system.
  -- The bit representation is as follows:
  -- 1 09876543 21098765432109876543210
  -- 8 76543210 12345678901234567890123
  -- 0 00000000 00000000000000000000000
  -- 8 7      0 -1                  -23
  -- +/-   exp.  fraction
  -----------------------------------------------------------------------------
  subtype float64 is float (11 downto -52);    -- IEEE 754 double precision
  -----------------------------------------------------------------------------
  -- IEEE-754 double precision floating point.  This is a "double float"
  -- in C, and a FLOAT*8 in Fortran.  The exponent is 11 bits wide, and
  -- the fraction is 52 bits wide.  This format can hold roughly 15 decimal
  -- digits.  Infinity is 2**2047 in this number system.
  -- The bit representation is as follows:
  --  3 21098765432 1098765432109876543210987654321098765432109876543210
  --  1 09876543210 1234567890123456789012345678901234567890123456789012
  --  S EEEEEEEEEEE FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
  -- 11 10        0 -1                                               -52
  -- +/-  exponent    fraction
  -----------------------------------------------------------------------------
  subtype float128 is float (15 downto -112);  -- IEEE 854 & C extended precision
  -----------------------------------------------------------------------------
  -- The 128 bit floating point number is "long double" in C (on
  -- some systems this is a 70 bit floating point number) and FLOAT*32
  -- in Fortran.  The exponent is 15 bits wide and the fraction is 112
  -- bits wide. This number can handel approximately 33 decimal digits.
  -- Infinity is 2**32,767 in this number system.
  -----------------------------------------------------------------------------
  -- purpose: Checks for a valid floating point number
  type valid_fpstate is (nan,           -- Signaling NaN (C FP_NAN)
                         quiet_nan,     -- Quiet NaN (C FP_NAN)
                         neg_inf,       -- Negative infinity (C FP_INFINITE)
                         neg_normal,    -- negative normalized nonzero
                         neg_denormal,  -- negative denormalized (FP_SUBNORMAL)
                         neg_zero,      -- -0 (C FP_ZERO)
                         pos_zero,      -- +0 (C FP_ZERO)
                         pos_denormal,  -- Positive denormalized (FP_SUBNORMAL)
                         pos_normal,    -- positive normalized nonzero
                         pos_inf,       -- positive infinity
                         isx);          -- at least one input is unknown

  -- This differed constant will tell you if the package body is synthesizable
  -- or implemented as real numbers.
  constant fphdlsynth_or_real : BOOLEAN;         -- differed constant
  -- Returns the class which X falls into
  function Class (
    x           : float;                         -- floating point input
    check_error : BOOLEAN := float_check_error)  -- check for errors
    return valid_fpstate;

  -- Arithmetic functions, these operators do not require parameters.
  function "abs" (arg  : float) return float;
  function "-" (arg    : float) return float;
  -- These allows the base math functions to use the default values
  -- of their parameters.  Thus they do full IEEE floating point.
  function "+" (l, r   : float) return float;
  function "-" (l, r   : float) return float;
  function "*" (l, r   : float) return float;
  function "/" (l, r   : float) return float;
  function "rem" (l, r : float) return float;
  function "mod" (l, r : float) return float;
  -- Basic parameter list
  -- round_style - Selects the rounding algorithm to use
  -- guard - extra bits added to the end if the operation to add precision
  -- check_error - When "false" turns off NAN and overflow checks
  -- denormalize - When "false" turns off denormal number processing
  function add (
    l, r                 : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  function subtract (
    l, r                 : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  function multiply (
    l, r                 : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  function divide (
    l, r                 : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  function remainder (
    l, r                 : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  function modulo (
    l, r                 : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  -- reciprocal
  function reciprocal (
    arg                  : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  function dividebyp2 (
    l, r                 : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  -- Multiply accumumlate  result = l*r + c
  function mac (
    l, r, c              : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  function Is_Negative (arg : float) return BOOLEAN;

  -----------------------------------------------------------------------------
  -- compare functions
  -- =, /=, >=, <=, <, >, maximum, minimum
  -- These functions are intentionally not implemented in this package,
  -- use the "fphdl_pkg" to get this funcitonality.
  function eq (                         -- equal =
    l, r                 : float;       -- floating point input
    constant check_error : BOOLEAN := float_check_error;
    constant denormalize : BOOLEAN := float_denormalize)
    return BOOLEAN;

  function ne (                         -- not equal /=
    l, r                 : float;       -- floating point input
    constant check_error : BOOLEAN := float_check_error;
    constant denormalize : BOOLEAN := float_denormalize)
    return BOOLEAN;

  function lt (                         -- less than <
    l, r                 : float;       -- floating point input
    constant check_error : BOOLEAN := float_check_error;
    constant denormalize : BOOLEAN := float_denormalize)
    return BOOLEAN;

  function gt (                         -- greater than >
    l, r                 : float;       -- floating point input
    constant check_error : BOOLEAN := float_check_error;
    constant denormalize : BOOLEAN := float_denormalize)
    return BOOLEAN;

  function le (                         -- less than or equal to <=
    l, r                 : float;       -- floating point input
    constant check_error : BOOLEAN := float_check_error;
    constant denormalize : BOOLEAN := float_denormalize)
    return BOOLEAN;

  function ge (                         -- greater than or equal to >=
    l, r                 : float;       -- floating point input
    constant check_error : BOOLEAN := float_check_error;
    constant denormalize : BOOLEAN := float_denormalize)
    return BOOLEAN;
  -- Need to overload the default versions of these
  function "=" (l, r     : float) return BOOLEAN;
  function "/=" (l, r    : float) return BOOLEAN;
  function ">=" (l, r    : float) return BOOLEAN;
  function "<=" (l, r    : float) return BOOLEAN;
  function ">" (l, r     : float) return BOOLEAN;
  function "<" (l, r     : float) return BOOLEAN;
  --%%% Uncomment the following (new syntax)
--  function "?=" (l, r : float) return STD_ULOGIC;
--  function "?\=" (l, r : float) return STD_ULOGIC;
--  function "?>" (l, r : float) return STD_ULOGIC;
--  function "?>=" (l, r : float) return STD_ULOGIC;
--  function "?<" (l, r : float) return STD_ULOGIC;
--  function "?<=" (l, r : float) return STD_ULOGIC;
  --%%% remove the following (old syntax)
  function \?=\ (l, r  : float) return STD_ULOGIC;
  function \?/=\ (l, r : float) return STD_ULOGIC;
  function \?>\  (l, r : float) return STD_ULOGIC;
  function \?>=\ (l, r : float) return STD_ULOGIC;
  function \?<\  (l, r : float) return STD_ULOGIC;
  function \?<=\ (l, r : float) return STD_ULOGIC;
  function std_match (l, r   : float) return BOOLEAN;
  function find_lsb (arg : float; y : STD_ULOGIC) return INTEGER;
  function find_msb (arg : float; y : STD_ULOGIC) return INTEGER;
  function maximum (l, r : float) return float;
  function minimum (l, r : float) return float;
  -- conversion functions
  -- Converts one floating point number into another.
  function resize (
    arg                     : float;    -- Floating point input
    constant exponent_width : NATURAL    := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- length of FP output fraction
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant check_error    : BOOLEAN    := float_check_error;
    constant denormalize_in : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant denormalize    : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  function resize (
    arg                     : float;    -- Floating point input
    size_res                : float;
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant check_error    : BOOLEAN    := float_check_error;
    constant denormalize_in : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant denormalize    : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  function to_float32 (
    arg                     : float;
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant check_error    : BOOLEAN    := float_check_error;
    constant denormalize_in : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant denormalize    : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  function to_float64 (
    arg                     : float;
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant check_error    : BOOLEAN    := float_check_error;
    constant denormalize_in : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant denormalize    : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  function to_float128 (
    arg                     : float;
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant check_error    : BOOLEAN    := float_check_error;
    constant denormalize_in : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant denormalize    : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  -- Converts an fp into an SLV (needed for synthesis)
  function to_slv (arg : float) return STD_LOGIC_VECTOR;
--  alias to_StdLogicVector is to_slv [float return STD_LOGIC_VECTOR];
--  alias to_Std_Logic_Vector is to_slv [float return STD_LOGIC_VECTOR];

  -- Converts an fp into an SULV
  function to_sulv (arg : float) return STD_ULOGIC_VECTOR;
--  alias to_StdULogicVector is to_sulv [float return STD_ULOGIC_VECTOR];
--  alias to_Std_ULogic_Vector is to_sulv [float return STD_ULOGIC_VECTOR];

  -- std_logic_vector to float
  function to_float (
    arg                     : STD_LOGIC_VECTOR;
    constant exponent_width : NATURAL := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- length of FP output fraction
    return float;

  -- std_ulogic_vector to float
  function to_float (
    arg                     : STD_ULOGIC_VECTOR;
    constant exponent_width : NATURAL := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- length of FP output fraction
    return float;

  -- Integer to float
  function to_float (
    arg                     : INTEGER;
    constant exponent_width : NATURAL    := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- length of FP output fraction
    constant round_style    : round_type := float_round_style)  -- rounding option
    return float;

  -- real to float
  function to_float (
    arg                     : REAL;
    constant exponent_width : NATURAL    := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- length of FP output fraction
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant denormalize    : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  -- unsigned to float
  function to_float (
    arg                     : UNSIGNED;
    constant exponent_width : NATURAL    := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- length of FP output fraction
    constant round_style    : round_type := float_round_style)  -- rounding option
    return float;

  -- signed to float
  function to_float (
    arg                     : SIGNED;
    constant exponent_width : NATURAL    := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- length of FP output fraction
    constant round_style    : round_type := float_round_style)  -- rounding option
    return float;

  -- unsigned fixed point to float
  function to_float (
    arg                     : ufixed;   -- unsigned fixed point input
    constant exponent_width : NATURAL    := float_exponent_width;  -- width of exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- width of fraction
    constant round_style    : round_type := float_round_style;  -- rounding
    constant denormalize    : BOOLEAN    := float_denormalize)  -- use ieee extentions
    return float;

  -- signed fixed point to float
  function to_float (
    arg                     : sfixed;
    constant exponent_width : NATURAL    := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- length of FP output fraction
    constant round_style    : round_type := float_round_style;  -- rounding
    constant denormalize    : BOOLEAN    := float_denormalize)  -- rounding option
    return float;

  -- size_res functions
  -- Integer to float
  function to_float (
    arg                  : INTEGER;
    size_res             : float;
    constant round_style : round_type := float_round_style)  -- rounding option
    return float;

  -- real to float
  function to_float (
    arg                  : REAL;
    size_res             : float;
    constant round_style : round_type := float_round_style;  -- rounding option
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  -- unsigned to float
  function to_float (
    arg                  : UNSIGNED;
    size_res             : float;
    constant round_style : round_type := float_round_style)  -- rounding option
    return float;

  -- signed to float
  function to_float (
    arg                  : SIGNED;
    size_res             : float;
    constant round_style : round_type := float_round_style)  -- rounding option
    return float;

  -- slv to float
  function to_float (
    arg      : STD_LOGIC_VECTOR;
    size_res : float)
    return float;

  -- sulv to float
  function to_float (
    arg      : STD_ULOGIC_VECTOR;
    size_res : float)
    return float;

  -- unsigned fixed point to float
  function to_float (
    arg                  : ufixed;      -- unsigned fixed point input
    size_res             : float;
    constant round_style : round_type := float_round_style;  -- rounding
    constant denormalize : BOOLEAN    := float_denormalize)  -- use ieee extentions
    return float;

  -- signed fixed point to float
  function to_float (
    arg                  : sfixed;
    size_res             : float;
    constant round_style : round_type := float_round_style;  -- rounding
    constant denormalize : BOOLEAN    := float_denormalize)  -- rounding option
    return float;

  -- float to unsigned
  function to_unsigned (
    arg                  : float;       -- floating point input
    constant size        : NATURAL;     -- length of output
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant round_style : round_type := float_round_style)  -- rounding option
    return UNSIGNED;

  -- float to signed
  function to_signed (
    arg                  : float;       -- floating point input
    constant size        : NATURAL;     -- length of output
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant round_style : round_type := float_round_style)  -- rounding option
    return SIGNED;

  -- purpose: Converts a float to unsigned fixed point
  function to_ufixed (
    arg                     : float;    -- fp input
    constant left_index     : INTEGER;  -- integer part
    constant right_index    : INTEGER;  -- fraction part
    constant round_style    : BOOLEAN := fixed_round_style;  -- rounding
    constant overflow_style : BOOLEAN := fixed_overflow_style;  -- saturate
    constant check_error    : BOOLEAN := float_check_error;  -- check for errors
    constant denormalize    : BOOLEAN := float_denormalize)
    return ufixed;

  -- float to signed fixed point
  function to_sfixed (
    arg                     : float;    -- fp input
    constant left_index     : INTEGER;  -- integer part
    constant right_index    : INTEGER;  -- fraction part
    constant round_style    : BOOLEAN := fixed_round_style;  -- rounding
    constant overflow_style : BOOLEAN := fixed_overflow_style;  -- saturate
    constant check_error    : BOOLEAN := float_check_error;  -- check for errors
    constant denormalize    : BOOLEAN := float_denormalize)
    return sfixed;

  -- size_res versions
  -- float to unsigned
  function to_unsigned (
    arg                  : float;       -- floating point input
    size_res             : UNSIGNED;
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant round_style : round_type := float_round_style)  -- rounding option
    return UNSIGNED;

  -- float to signed
  function to_signed (
    arg                  : float;       -- floating point input
    size_res             : SIGNED;
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant round_style : round_type := float_round_style)  -- rounding option
    return SIGNED;

  -- purpose: Converts a float to unsigned fixed point
  function to_ufixed (
    arg                     : float;    -- fp input
    size_res                : ufixed;
    constant round_style    : BOOLEAN := fixed_round_style;  -- rounding
    constant overflow_style : BOOLEAN := fixed_overflow_style;  -- saturate
    constant check_error    : BOOLEAN := float_check_error;  -- check for errors
    constant denormalize    : BOOLEAN := float_denormalize)
    return ufixed;

  -- float to signed fixed point
  function to_sfixed (
    arg                     : float;    -- fp input
    size_res                : sfixed;
    constant round_style    : BOOLEAN := fixed_round_style;  -- rounding
    constant overflow_style : BOOLEAN := fixed_overflow_style;  -- saturate
    constant check_error    : BOOLEAN := float_check_error;  -- check for errors
    constant denormalize    : BOOLEAN := float_denormalize)
    return sfixed;

  -- float to real
  function to_real (
    arg                  : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return REAL;

  -- float to integer
  function to_integer (
    arg                  : float;       -- floating point input
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant round_style : round_type := float_round_style)  -- rounding option
    return INTEGER;

  -- Maps metalogical values
  function to_01 (
    arg  : float;                       -- floating point input
    XMAP : STD_LOGIC := '0')
    return float;

  function Is_X (arg   : float) return BOOLEAN;
  function to_X01 (arg : float) return float;
  function to_X01Z (arg : float) return float;
  function to_UX01 (arg : float) return float;

  -- These two procedures were copied out of the body because they proved
  -- very useful for vendor specific algorithm development
  -- Break_number converts a floating point number into it's parts
  -- Exponend is biased by -1
  procedure break_number (
    arg         : in  float;
    denormalize : in  BOOLEAN := float_denormalize;
    check_error : in  BOOLEAN := float_check_error;
    fract       : out UNSIGNED;
    expon       : out SIGNED;  -- NOTE:  Add 1 to get the real exponent!
    sign        : out STD_ULOGIC);

  procedure break_number (
    arg         : in  float;
    denormalize : in  BOOLEAN := float_denormalize;
    check_error : in  BOOLEAN := float_check_error;
    fract       : out ufixed;           -- a number between 1.0 and 2.0
    expon       : out SIGNED;  -- NOTE:  Add 1 to get the real exponent!
    sign        : out STD_ULOGIC);

  -- Normalize takes a fraction and and exponent and converts them into
  -- a floating point number.  Does the shifting and the rounding.
  -- Exponend is assumed to be biased by -1
  function normalize (
    fract                   : UNSIGNED;  -- fraction, unnormalized
    expon                   : SIGNED;   -- exponent - 1, normalized
    sign                    : STD_ULOGIC;                       -- sign bit
    sticky                  : STD_ULOGIC := '0';  -- Sticky bit (rounding)
    constant exponent_width : NATURAL    := float_exponent_width;  -- size of output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- size of output fraction
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant denormalize    : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant nguard         : NATURAL    := float_guard_bits)   -- guard bits
    return float;

  -- Exponend is assumed to be biased by -1
  function normalize (
    fract                   : ufixed;   -- unsigned fixed point
    expon                   : SIGNED;   -- exponent - 1, normalized
    sign                    : STD_ULOGIC;                       -- sign bit
    sticky                  : STD_ULOGIC := '0';  -- Sticky bit (rounding)
    constant exponent_width : NATURAL    := float_exponent_width;  -- size of output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- size of output fraction
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant denormalize    : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant nguard         : NATURAL    := float_guard_bits)   -- guard bits
    return float;

  function normalize (
    fract                : UNSIGNED;    -- unsigned
    expon                : SIGNED;      -- exponent - 1, normalized
    sign                 : STD_ULOGIC;  -- sign bit
    sticky               : STD_ULOGIC := '0';  -- Sticky bit (rounding)
    size_res             : float;       -- used for sizing only
    constant round_style : round_type := float_round_style;  -- rounding option
    constant denormalize : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant nguard      : NATURAL    := float_guard_bits)   -- guard bits
    return float;

  -- Exponend is assumed to be biased by -1
  function normalize (
    fract                : ufixed;      -- unsigned fixed point
    expon                : SIGNED;      -- exponent - 1, normalized
    sign                 : STD_ULOGIC;  -- sign bit
    sticky               : STD_ULOGIC := '0';  -- Sticky bit (rounding)
    size_res             : float;       -- used for sizing only
    constant round_style : round_type := float_round_style;  -- rounding option
    constant denormalize : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant nguard      : NATURAL    := float_guard_bits)   -- guard bits
    return float;

  -- overloaded versions
  function "+" (l   : float; r : REAL) return float;
  function "+" (l   : REAL; r : float) return float;
  function "+" (l   : float; r : INTEGER) return float;
  function "+" (l   : INTEGER; r : float) return float;
  function "-" (l   : float; r : REAL) return float;
  function "-" (l   : REAL; r : float) return float;
  function "-" (l   : float; r : INTEGER) return float;
  function "-" (l   : INTEGER; r : float) return float;
  function "*" (l   : float; r : REAL) return float;
  function "*" (l   : REAL; r : float) return float;
  function "*" (l   : float; r : INTEGER) return float;
  function "*" (l   : INTEGER; r : float) return float;
  function "/" (l   : float; r : REAL) return float;
  function "/" (l   : REAL; r : float) return float;
  function "/" (l   : float; r : INTEGER) return float;
  function "/" (l   : INTEGER; r : float) return float;
  function "rem" (l : float; r : REAL) return float;
  function "rem" (l : REAL; r : float) return float;
  function "rem" (l : float; r : INTEGER) return float;
  function "rem" (l : INTEGER; r : float) return float;
  function "mod" (l : float; r : REAL) return float;
  function "mod" (l : REAL; r : float) return float;
  function "mod" (l : float; r : INTEGER) return float;
  function "mod" (l : INTEGER; r : float) return float;
  function "=" (l   : float; r : REAL) return BOOLEAN;
  function "/=" (l  : float; r : REAL) return BOOLEAN;
  function ">=" (l  : float; r : REAL) return BOOLEAN;
  function "<=" (l  : float; r : REAL) return BOOLEAN;
  function ">" (l   : float; r : REAL) return BOOLEAN;
  function "<" (l   : float; r : REAL) return BOOLEAN;
  function "=" (l   : REAL; r : float) return BOOLEAN;
  function "/=" (l  : REAL; r : float) return BOOLEAN;
  function ">=" (l  : REAL; r : float) return BOOLEAN;
  function "<=" (l  : REAL; r : float) return BOOLEAN;
  function ">" (l   : REAL; r : float) return BOOLEAN;
  function "<" (l   : REAL; r : float) return BOOLEAN;
  function "=" (l   : float; r : INTEGER) return BOOLEAN;
  function "/=" (l  : float; r : INTEGER) return BOOLEAN;
  function ">=" (l  : float; r : INTEGER) return BOOLEAN;
  function "<=" (l  : float; r : INTEGER) return BOOLEAN;
  function ">" (l   : float; r : INTEGER) return BOOLEAN;
  function "<" (l   : float; r : INTEGER) return BOOLEAN;
  function "=" (l   : INTEGER; r : float) return BOOLEAN;
  function "/=" (l  : INTEGER; r : float) return BOOLEAN;
  function ">=" (l  : INTEGER; r : float) return BOOLEAN;
  function "<=" (l  : INTEGER; r : float) return BOOLEAN;
  function ">" (l   : INTEGER; r : float) return BOOLEAN;
  function "<" (l   : INTEGER; r : float) return BOOLEAN;

  ----------------------------------------------------------------------------
  -- logical functions
  ----------------------------------------------------------------------------
  function "not" (L         : float) return float;
  function "and" (L, R      : float) return float;
  function "or" (L, R       : float) return float;
  function "nand" (L, R     : float) return float;
  function "nor" (L, R      : float) return float;
  function "xor" (L, R      : float) return float;
  function "xnor" (L, R     : float) return float;
  -- Vector and std_ulogic functions, same as functions in numeric_std
  function "and" (L         : STD_ULOGIC; R : float) return float;
  function "and" (L         : float; R : STD_ULOGIC) return float;
  function "or" (L          : STD_ULOGIC; R : float) return float;
  function "or" (L          : float; R : STD_ULOGIC) return float;
  function "nand" (L        : STD_ULOGIC; R : float) return float;
  function "nand" (L        : float; R : STD_ULOGIC) return float;
  function "nor" (L         : STD_ULOGIC; R : float) return float;
  function "nor" (L         : float; R : STD_ULOGIC) return float;
  function "xor" (L         : STD_ULOGIC; R : float) return float;
  function "xor" (L         : float; R : STD_ULOGIC) return float;
  function "xnor" (L        : STD_ULOGIC; R : float) return float;
  function "xnor" (L        : float; R : STD_ULOGIC) return float;
  -- Reduction operators, same as numeric_std functions
  -- %%% remove 6 functions (old syntax)
  function and_reduce (arg  : float) return STD_ULOGIC;
  function nand_reduce (arg : float) return STD_ULOGIC;
  function or_reduce (arg   : float) return STD_ULOGIC;
  function nor_reduce (arg  : float) return STD_ULOGIC;
  function xor_reduce (arg  : float) return STD_ULOGIC;
  function xnor_reduce (arg : float) return STD_ULOGIC;
  -- %%% Uncomment the following 6 functions (new syntax)
  -- function "and" (arg  : float) RETURN std_ulogic;
  -- function "nand" (arg  : float) RETURN std_ulogic;
  -- function "or" (arg  : float) RETURN std_ulogic;
  -- function "nor" (arg  : float) RETURN std_ulogic;
  -- function "xor" (arg  : float) RETURN std_ulogic;
  -- function "xnor" (arg  : float) RETURN std_ulogic;

  -- Note: "sla", "sra", "sll", "slr", "rol" and "ror" not implemented.
  -- Note: "find_msb" and "find_lsb" not implemented, use "logb".
  -----------------------------------------------------------------------------
  -- Recommended Functions from the IEEE 754 Appendix
  -----------------------------------------------------------------------------
  -- returns x with the sign of y.
  function Copysign (x, y : float) return float;

  -- Returns y * 2**n for intergral values of N without computing 2**n
  function Scalb (
    y                    : float;       -- floating point input
    N                    : INTEGER;     -- exponent to add    
    constant round_style : round_type := float_round_style;  -- rounding option
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  -- Returns y * 2**n for intergral values of N without computing 2**n
  function Scalb (
    y                    : float;       -- floating point input
    N                    : SIGNED;      -- exponent to add    
    constant round_style : round_type := float_round_style;  -- rounding option
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float;

  -- returns the unbiased exponent of x
  function Logb (x : float) return INTEGER;
  function Logb (x : float) return SIGNED;

  -- returns the next represtable neighbor of x in the direction toward y
  function Nextafter (
    x, y                 : float;       -- floating point input
    constant check_error : BOOLEAN := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN := float_denormalize)
    return float;

  -- Returns TRUE if X is unordered with Y.
  function Unordered (x, y : float) return BOOLEAN;
  function Finite (x       : float) return BOOLEAN;
  function Isnan (x        : float) return BOOLEAN;

  -- Function to return constants.
  function zerofp (
    constant exponent_width : NATURAL := float_exponent_width;  -- exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- fraction
    return float;
  function nanfp (
    constant exponent_width : NATURAL := float_exponent_width;  -- exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- fraction
    return float;
  function qnanfp (
    constant exponent_width : NATURAL := float_exponent_width;  -- exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- fraction
    return float;
  function pos_inffp (
    constant exponent_width : NATURAL := float_exponent_width;  -- exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- fraction
    return float;
  function neg_inffp (
    constant exponent_width : NATURAL := float_exponent_width;  -- exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- fraction
    return float;
  function neg_zerofp (
    constant exponent_width : NATURAL := float_exponent_width;  -- exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- fraction
    return float;
  -- size_res versions
  function zerofp (
    size_res : float)                   -- variable is only use for sizing
    return float;
  function nanfp (
    size_res : float)                   -- variable is only use for sizing
    return float;
  function qnanfp (
    size_res : float)                   -- variable is only use for sizing
    return float;
  function pos_inffp (
    size_res : float)                   -- variable is only use for sizing
    return float;
  function neg_inffp (
    size_res : float)                   -- variable is only use for sizing
    return float;
  function neg_zerofp (
    size_res : float)                   -- variable is only use for sizing
    return float;

-- synthesis translate_off
-- rtl_synthesis off 
  -- impure functions
  -- writes S:EEEE:FFFFFFFF
  procedure write (
    L         : inout LINE;             -- access type (pointer)
    VALUE     : in    float;            -- value to write
    JUSTIFIED : in    SIDE  := right;   -- which side to justify text
    FIELD     : in    WIDTH := 0);      -- width of field

  -- Reads SEEEEFFFFFFFF, "." and ":" are ignored
  procedure READ(L : inout LINE; VALUE : out float);
  procedure READ(L : inout LINE; VALUE : out float; GOOD : out BOOLEAN);

  alias bread is READ [LINE, float, BOOLEAN];
  alias bread is READ [LINE, float];
  alias bwrite is WRITE [LINE, float, SIDE, WIDTH];

  procedure owrite (
    L         : inout LINE;             -- access type (pointer)
    VALUE     : in    float;            -- value to write
    JUSTIFIED : in    SIDE  := right;   -- which side to justify text
    FIELD     : in    WIDTH := 0);      -- width of field

  -- Octal read with padding, no seperaters used
  procedure OREAD(L : inout LINE; VALUE : out float);
  procedure OREAD(L : inout LINE; VALUE : out float; GOOD : out BOOLEAN);

  -- Hex write with padding, no seperators
  procedure hwrite (
    L         : inout LINE;             -- access type (pointer)
    VALUE     : in    float;            -- value to write
    JUSTIFIED : in    SIDE  := right;   -- which side to justify text
    FIELD     : in    WIDTH := 0);      -- width of field

  -- Hex read with padding, no seperaters used
  procedure HREAD(L : inout LINE; VALUE : out float);
  procedure HREAD(L : inout LINE; VALUE : out float; GOOD : out BOOLEAN);

  -- returns "S:EEEE:FFFFFFFF"
  function to_string (
    value     : float;
    justified : SIDE  := right;
    field     : WIDTH := 0
    ) return STRING;

  -- Returns a HEX string, with padding
  function to_hstring (
    value     : float;
    justified : SIDE  := right;
    field     : WIDTH := 0
    ) return STRING;

  -- Returns and octal string, with padding
  function to_ostring (
    value     : float;
    justified : SIDE  := right;
    field     : WIDTH := 0
    ) return STRING;

  function from_string (
    bstring                 : STRING;   -- binary string
    constant exponent_width : NATURAL := float_exponent_width;
    constant fraction_width : NATURAL := float_fraction_width)
    return float;
  alias from_bstring is from_string [STRING, NATURAL, NATURAL return float];

  function from_ostring (
    ostring                 : STRING;   -- Octal string
    constant exponent_width : NATURAL := float_exponent_width;
    constant fraction_width : NATURAL := float_fraction_width)
    return float;

  function from_hstring (
    hstring                 : STRING;   -- hex string
    constant exponent_width : NATURAL := float_exponent_width;
    constant fraction_width : NATURAL := float_fraction_width)
    return float;

  function from_string (
    bstring  : STRING;                  -- binary string
    size_res : float)                   -- used for sizing only 
    return float;
  alias from_bstring is from_string [STRING, float return float];

  function from_ostring (
    ostring  : STRING;                  -- Octal string
    size_res : float)                   -- used for sizing only 
    return float;

  function from_hstring (
    hstring  : STRING;                  -- hex string
    size_res : float)                   -- used for sizing only 
    return float;

-- synthesis translate_on
-- rtl_synthesis on 

  function to_StdLogicVector (arg : float) return std_logic_vector ;
  function to_Std_Logic_Vector (arg : float) return std_logic_vector;
  function to_StdULogicVector (arg : float) return std_ulogic_vector ;
  function to_Std_ULogic_Vector (arg : float) return std_ulogic_vector;

end package float_pkg;
library ieee;
use ieee.math_real.all;
use ieee.std_logic_textio.all;          -- %%% for testing only
package body float_pkg is
  -- Author David Bishop (dbishop@vhdl.org)
  -----------------------------------------------------------------------------
  -- type declarations
  -----------------------------------------------------------------------------
  -- This differed constant will tell you if the package body is synthesizable
  -- or implemented as real numbers, set to "true" if synthesizable.
  constant fphdlsynth_or_real : BOOLEAN                       := true;  -- differed constant
  -- types of boundary conditions
  type     boundary_type is (normal, infinity, zero, denormal);
  -- null range array constant
  constant NAFP               : float (0 downto 1)            := (others => '0');
  constant NSLV               : STD_LOGIC_VECTOR (0 downto 1) := (others => '0');

  -- %%% These functions can be removed in the final release.
  -- %%% Replace and_reducex with "and" (and all similar _reducex functions)
  -- purpose: AND all of the bits in a vector together
  -- This is a copy of the proposed "and_reduce" from 1076.3
  function and_reducex (arg : STD_LOGIC_VECTOR)
    return STD_LOGIC is
    variable Upper, Lower : STD_LOGIC;
    variable Half         : INTEGER;
    variable BUS_int      : STD_LOGIC_VECTOR (arg'length - 1 downto 0);
    variable Result       : STD_LOGIC;
  begin
    if (arg'length < 1) then            -- In the case of a NULL range
      Result := '1';                    -- Change for version 1.3
    else
      BUS_int := to_ux01 (arg);
      if (BUS_int'length = 1) then
        Result := BUS_int (BUS_int'left);
      elsif (BUS_int'length = 2) then
        Result := BUS_int (BUS_int'right) and BUS_int (BUS_int'left);
      else
        Half   := (BUS_int'length + 1) / 2 + BUS_int'right;
        Upper  := and_reducex (BUS_int (BUS_int'left downto Half));
        Lower  := and_reducex (BUS_int (Half - 1 downto BUS_int'right));
        Result := Upper and Lower;
      end if;
    end if;
    return Result;
  end function and_reducex;

  function and_reducex (arg : UNSIGNED)
    return STD_LOGIC is
  begin
    return and_reducex (STD_LOGIC_VECTOR (arg));
  end function and_reducex;

  -- purpose: OR all of the bits in a vector together
  -- This is a copy of the proposed "and_reduce" from 1076.3
  function or_reducex (arg : STD_LOGIC_VECTOR)
    return STD_LOGIC is
    variable Upper, Lower : STD_LOGIC;
    variable Half         : INTEGER;
    variable BUS_int      : STD_LOGIC_VECTOR (arg'length - 1 downto 0);
    variable Result       : STD_LOGIC;
  begin
    if (arg'length < 1) then            -- In the case of a NULL range
      Result := '0';
    else
      BUS_int := to_ux01 (arg);
      if (BUS_int'length = 1) then
        Result := BUS_int (BUS_int'left);
      elsif (BUS_int'length = 2) then
        Result := BUS_int (BUS_int'right) or BUS_int (BUS_int'left);
      else
        Half   := (BUS_int'length + 1) / 2 + BUS_int'right;
        Upper  := or_reducex (BUS_int (BUS_int'left downto Half));
        Lower  := or_reducex (BUS_int (Half - 1 downto BUS_int'right));
        Result := Upper or Lower;
      end if;
    end if;
    return Result;
  end function or_reducex;

  function or_reducex (arg : UNSIGNED)
    return STD_LOGIC is
  begin
    return or_reducex (STD_LOGIC_VECTOR (arg));
  end function or_reducex;

  function xor_reducex (arg : STD_LOGIC_VECTOR) return STD_ULOGIC is
    variable Upper, Lower : STD_ULOGIC;
    variable Half         : INTEGER;
    variable BUS_int      : STD_LOGIC_VECTOR (arg'length - 1 downto 0);
    variable Result       : STD_ULOGIC := '0';  -- In the case of a NULL range
  begin
    if (arg'length >= 1) then
      BUS_int := to_ux01 (arg);
      if (BUS_int'length = 1) then
        Result := BUS_int (BUS_int'left);
      elsif (BUS_int'length = 2) then
        Result := BUS_int(BUS_int'right) xor BUS_int(BUS_int'left);
      else
        Half   := (BUS_int'length + 1) / 2 + BUS_int'right;
        Upper  := xor_reducex (BUS_int (BUS_int'left downto Half));
        Lower  := xor_reducex (BUS_int (Half - 1 downto BUS_int'right));
        Result := Upper xor Lower;
      end if;
    end if;
    return Result;
  end function xor_reducex;

  -- purpose: To find the largest of 2 numbers
  -- %%% Will be implicit in VHDL-200X
  function maximum (
    l, r : INTEGER)                     -- inputs
    return INTEGER is
  begin  -- function max
    if l > r then return l;
    else return r;
    end if;
  end function maximum;

  -- purpose: Find the first "1" is a vector, starting from the MSB
  -- %%% This is a copy of the proposed "find_msb" from 1076.3
  function find_msb (
    arg : UNSIGNED;                     -- vector argument
    y   : STD_ULOGIC)                   -- look for this bit
    return INTEGER is
    alias xarg : UNSIGNED(arg'length-1 downto 0) is arg;
  begin
    for_loop : for i in xarg'range loop
      if xarg(i) = y then
        return i;
      end if;
    end loop;
    return -1;
  end function find_msb;
  -- %%% End remove

  -- Special version of "minimum" to do some boundary checking
  function minx (l, r : INTEGER)
    return INTEGER is
  begin  -- function minimum
    if (L = INTEGER'low or R = INTEGER'low) then
      report "FLOAT_GENERIC_PKG: Unbounded number passed, was a literal used?"
        severity error;
      return 0;
    end if;
    if L > R then return R;
    else return L;
    end if;
  end function minx;

  -- Generates the base number for the exponent normalization offset.
  function gen_expon_base (
    constant exponent_width : NATURAL)
    return SIGNED is
    variable result : SIGNED (exponent_width-1 downto 0);
  begin
    result                    := (others => '1');
    result (exponent_width-1) := '0';
    return result;
  end function gen_expon_base;

  -- purpose: Test the boundary conditions of a Real number
--  function test_boundary (
--    arg                     : REAL;     -- Input, converted to real
--    constant fraction_width : NATURAL;  -- length of FP output fraction
--    constant exponent_width : NATURAL;  -- length of FP exponent
--    constant denormalize    : BOOLEAN := true)  -- Use IEEE extended FP
--    return boundary_type is
--    constant expon_base : SIGNED (exponent_width-1 downto 0) :=
--      gen_expon_base(exponent_width);   -- exponent offset
--    constant exp_min : SIGNED (12 downto 0) :=
--      -(resize(expon_base, 13)) +1;     -- Minimum normal exponent
--    constant exp_ext_min : SIGNED (12 downto 0) :=
--      exp_min - fraction_width;         -- Minimum for denormal exponent
--  begin  -- function test_boundary
--    -- Check to see if the exponent is big enough
--    -- Note that the argument is always an absolute value at this point.
--    if arg = 0.0 then
--      return zero;
--    elsif exponent_width > 11 then      -- Exponent for Real is 11 (64 bit)
--      return normal;
--    else
--      if arg < 2.0 ** to_integer(exp_min) then
--        if denormalize then
--          if arg < 2.0 ** to_integer(exp_ext_min) then
--            return zero;
--          else
--            return denormal;
--          end if;
--        else
--          if arg < 2.0 ** to_integer(exp_min-1) then
--            return zero;
--          else
--            return normal;              -- Can still represent this number
--          end if;
--        end if;
--      elsif exponent_width < 11 then
--        if arg >= 2.0 ** (to_integer(expon_base)+1) then
--          return infinity;
--        else
--          return normal;
--        end if;
--      else
--        return normal;
--      end if;
--    end if;
--  end function test_boundary;

  -- Some synthesis tools don't like this function, so do it this way
  -- (ignoring denormal and infinite numbers)
  function test_boundary (
    arg                     : REAL;     -- Input, converted to real
    constant fraction_width : NATURAL;  -- length of FP output fraction
    constant exponent_width : NATURAL;  -- length of FP exponent
    constant denormalize    : BOOLEAN := true)  -- Use IEEE extended FP
    return boundary_type is
  begin  -- function test_boundary
    if arg = 0.0 then
      return zero;
    else
      return normal;
    end if;
  end function test_boundary;

  -- purpose: Rounds depending on the state of the "round_style"
  -- unsigned version
  function check_round (
    fract_in             : STD_ULOGIC;  -- input fraction
    sign                 : STD_ULOGIC;  -- sign bit
    remainder            : UNSIGNED;    -- remainder to round from
    sticky               : STD_ULOGIC := '0';  -- Sticky bit
    constant round_style : round_type)  -- rounding type
    return BOOLEAN is
    variable result     : BOOLEAN;
    variable or_reduced : STD_ULOGIC;
  begin  -- function check_round
    result := false;
    if (remainder'length > 0) then      -- if remainder in a null array
      or_reduced := or_reducex (remainder & sticky);
      rounding_case : case round_style is
        when round_nearest =>           -- Round Nearest, default mode
          if remainder(remainder'high) = '1' then  -- round
            if (remainder'length > 1) then
              if ((or_reducex (remainder(remainder'high-1
                                        downto remainder'low)) = '1'
                   or sticky = '1')
                  or fract_in = '1') then
                -- Make the bottom bit zero if possible if we are at 1/2
                result := true;
              end if;
            else
              result := (fract_in = '1' or sticky = '1');
            end if;
          end if;
        when round_inf =>               -- round up if positive, else truncate.
          if or_reduced = '1' and sign = '0' then
            result := true;
          end if;
        when round_neginf =>        -- round down if negative, else truncate.
          if or_reduced = '1' and sign = '1' then
            result := true;
          end if;
        when round_zero =>              -- round toward 0   Truncate
          null;
      end case rounding_case;
    end if;
    return result;
  end function check_round;

  -- purpose: Rounds depending on the state of the "round_style"
  -- unsigned version
  procedure fp_round (
    fract_in  : in  UNSIGNED;            -- input fraction
    expon_in  : in  SIGNED;              -- input exponent
    fract_out : out UNSIGNED;            -- output fraction
    expon_out : out SIGNED) is           -- output exponent
  begin  -- procedure fp_round
    if and_reducex(fract_in) = '1' then  -- Fraction is all "1"
      expon_out := expon_in + 1;
      fract_out := to_unsigned(0, fract_out'high+1);
    else
      expon_out := expon_in;
      fract_out := fract_in + 1;
    end if;
  end procedure fp_round;

  -- Integer version of the "log2" command
  -- Synthisable, used by to_float(integer) function
  function log2(A : NATURAL) return NATURAL is
  begin
    for I in 1 to 30 loop               -- Works for up to 32 bit integers
      if (2**I > A) then return(I-1);
      end if;
    end loop;
    return(30);
  end function log2;

  -- purpose: Look for the boundaries of the integer input
  -- Synthisable
  function fp_input_type (
    arg                     : INTEGER;  -- integer input
    constant fraction_width : NATURAL;  -- length of FP output fraction
    constant exponent_width : NATURAL)  -- length of FP output exponent
    return boundary_type is
    constant expon_base : SIGNED (exponent_width-1 downto 0) :=
      gen_expon_base(exponent_width);   -- exponent offset
    variable maxint : INTEGER;
  begin  -- function fp_input_type
    if arg = 0 then
      return zero;
    elsif exponent_width > 5 then       -- largest possible integer = 2**31
      return normal;
    else
      maxint := 2 ** (to_integer(expon_base)+1);
      -- worry about infinity
      if arg >= maxint then
        return infinity;
      else
        return normal;
      end if;
    end if;
  end function fp_input_type;

  procedure break_number (              -- internal version
    arg         : in  float;
    fptyp       : in  valid_fpstate;
    denormalize : in  BOOLEAN := true;
    fract       : out UNSIGNED;
    expon       : out SIGNED) is
    constant fraction_width : NATURAL                            := -arg'low;  -- length of FP output fraction
    constant exponent_width : NATURAL                            := arg'high;  -- length of FP output exponent
    constant expon_base     : SIGNED (exponent_width-1 downto 0) :=
      gen_expon_base(exponent_width);   -- exponent offset
    variable exp : SIGNED (expon'range);
  begin
    fract (fraction_width-1 downto 0) :=
      UNSIGNED (to_slv(arg(-1 downto -fraction_width)));
    breakcase : case fptyp is
      when pos_zero | neg_zero =>
        fract (fraction_width) := '0';
        exp                    := -expon_base;
      when pos_denormal | neg_denormal =>
        if denormalize then
          exp                    := -expon_base;
          fract (fraction_width) := '0';
        else
          exp                    := -expon_base - 1;
          fract (fraction_width) := '1';
        end if;
      when pos_normal | neg_normal =>
        fract (fraction_width) := '1';
        exp                    := SIGNED(arg(exponent_width-1 downto 0));
        exp (exponent_width-1) := not exp(exponent_width-1);
      when others =>
        assert NO_WARNING
          report "FLOAT_GENERIC_PKG.BREAK_NUMBER: " &
          "Meta state detected in fp_break_number process"
          severity warning;
        -- complete the case, if a NAN goes in, a NAN comes out.
        exp                    := (others => '1');
        fract (fraction_width) := '1';
    end case breakcase;
    expon := exp;
  end procedure break_number;

  -- purpose: floating point to UNSIGNED
  -- Used by to_integer, to_unsigned, and to_signed functions
  procedure float_to_unsigned (
    arg                  : in  float;   -- floating point input
    variable sign        : out STD_ULOGIC;          -- sign of output
    variable frac        : out UNSIGNED;            -- unsigned biased output
    constant denormalize : in  BOOLEAN;             -- turn on denormalization
    constant bias        : in  NATURAL;             -- bias for fixed point
    constant round_style : in  round_type) is       -- rounding method
    constant fraction_width : INTEGER := -minx(arg'low, arg'low);  -- length of FP output fraction
    constant exponent_width : INTEGER := arg'high;  -- length of FP output exponent
    variable fract          : UNSIGNED (frac'range);  -- internal version of frac
    variable isign          : STD_ULOGIC;           -- internal version of sign
    variable exp            : INTEGER;  -- Exponent
    variable expon          : SIGNED (exponent_width-1 downto 0);  -- Vectorized exp
    -- Base to divide fraction by
    variable frac_shift     : UNSIGNED (frac'high+3 downto 0);  -- Fraction shifted
    variable shift          : INTEGER;
    variable remainder      : UNSIGNED (2 downto 0);
    variable round          : STD_ULOGIC;           -- round BIT
  begin
    isign                   := to_x01(arg(arg'high));
    -- exponent /= '0', normal floating point
    expon                   := to_01(SIGNED(arg (exponent_width-1 downto 0)), 'X');
    expon(exponent_width-1) := not expon(exponent_width-1);
    exp                     := to_integer (expon);
    -- Figure out the fraction
    fract                   := (others => '0');     -- fill with zero
    fract (fract'high)      := '1';     -- Add the "1.0".
    shift                   := (fract'high-1) - exp;
    if fraction_width > fract'high then             -- Can only use size-2 bits
      fract (fract'high-1 downto 0) := UNSIGNED (to_slv (arg(-1 downto
                                                             -fract'high)));
    else                                -- can use all bits
      fract (fract'high-1 downto fract'high-fraction_width) :=
        UNSIGNED (to_slv (arg(-1 downto -fraction_width)));
    end if;
    frac_shift := fract & "000";
    if shift < 0 then                   -- Overflow
      fract := (others => '1');
    else
      frac_shift := shift_right (frac_shift, shift);
      fract      := frac_shift (frac_shift'high downto 3);
      remainder  := frac_shift (2 downto 0);
      -- round (round_zero will bypass this and truncate)
      case round_style is
        when round_nearest =>
          round := remainder(2) and
                   (fract (0) or or_reducex (remainder (1 downto 0)));
        when round_inf =>
          round := remainder(2) and not isign;
        when round_neginf =>
          round := remainder(2) and isign;
        when others =>
          round := '0';
      end case;
      if round = '1' then
        fract := fract + 1;
      end if;
    end if;
    frac := fract;
    sign := isign;
  end procedure float_to_unsigned;

  -- purpose: returns a part of a string, this funciton is here because
  -- or_reducex (fractr (to_integer(shiftx) downto 0));
  -- can't be synthesized in some synthesis tools.
  function smallfract (
    arg : UNSIGNED;
    shift : natural)
    return std_ulogic is
    variable orx : STD_ULOGIC;
  begin
    orx := arg(shift);
    for i in arg'range loop
      if i < shift then
        orx := arg(i) or orx;
      end if;
    end loop;
    return orx;
  end function smallfract;
  ---------------------------------------------------------------------------
  -- Visible functions
  ---------------------------------------------------------------------------

  -- purpose: converts the negative index to a positive one
  -- negative indices are illegal in 1164 and 1076.3
  function to_slv (
    arg : float)                        -- fp vector
    return STD_LOGIC_VECTOR is
    subtype  t is STD_LOGIC_VECTOR(arg'length - 1 downto 0);
    variable slv : t;
  begin  -- function to_std_logic_vector
    if arg'length < 1 then
      return NSLV;
    end if;
    slv := t(arg);
--    floop : for i in slv'range loop
--      slv(i) := arg(i + arg'low);  -- slv(31) := arg (31-23)
--    end loop floop;
    return slv;
  end function to_slv;

  -- Converts an fp into an SULV
  function to_sulv (arg : float) return STD_ULOGIC_VECTOR is
  begin
    return to_stdulogicvector (to_slv(arg));
  end function to_sulv;
  
  -- purpose: normalizes a floating point number
  -- This version assumes an "unsigned" input with
  function normalize (
    fract                   : UNSIGNED;  -- fraction, unnormalized
    expon                   : SIGNED;   -- exponent, normalized by -1
    sign                    : STD_ULOGIC;                  -- sign BIT
    sticky                  : STD_ULOGIC := '0';  -- Sticky bit (rounding)
    constant exponent_width : NATURAL    := float_exponent_width;  -- size of output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- size of output fraction
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant denormalize    : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant nguard         : NATURAL    := float_guard_bits)  -- guard bits
    return float is
    variable sfract     : UNSIGNED (fract'high downto 0);  -- shifted fraction
    variable rfract     : UNSIGNED (fraction_width-1 downto 0);    -- fraction
    variable exp        : SIGNED (exponent_width+1 downto 0);  -- exponent
    variable rexp       : SIGNED (exponent_width+1 downto 0);  -- result exponent
    variable rexpon     : UNSIGNED (exponent_width-1 downto 0);    -- exponent
    variable result     : float (exponent_width downto -fraction_width);  -- result
    variable shiftr     : INTEGER;      -- shift amount
    constant expon_base : SIGNED (exponent_width-1 downto 0) :=
      gen_expon_base(exponent_width);   -- exponent offset
    variable round : BOOLEAN;
  begin  -- function normalize
    result (exponent_width) := sign;    -- sign bit
    round                   := false;
    shiftr                  := find_msb (to_01(fract), '1')  -- Find the first "1"
                               - fraction_width - nguard;  -- subtract the length we want
    exp := resize (expon, exp'length) + shiftr;
    if (or_reducex(fract) = '0') then   -- Zero
      result := zerofp (fraction_width => fraction_width,
                        exponent_width => exponent_width);
    elsif ((exp <= -resize(expon_base, exp'length)-1) and denormalize)
      or ((exp < -resize(expon_base, exp'length)-1) and not denormalize) then
      if (exp >= -resize(expon_base, exp'length)-fraction_width-1)
        and denormalize then
        exp    := -resize(expon_base, exp'length);
        shiftr := to_integer (expon + expon_base);         -- new shift
        sfract := fract sll shiftr;     -- shift
        if nguard > 0 then
          round := check_round (
            fract_in    => sfract (nguard),
            sign        => sign,
            remainder   => sfract(nguard-1 downto 0),
            round_style => round_style);
        end if;
        if round then
          fp_round(fract_in  => sfract (fraction_width-1+nguard downto nguard),
                   expon_in  => exp,
                   fract_out => rfract,
                   expon_out => rexp);
        else
          rfract := sfract (fraction_width-1+nguard downto nguard);
          rexp   := exp;
        end if;
        rexpon                             := UNSIGNED ((rexp(exponent_width-1 downto 0))-1);
        rexpon(exponent_width-1)           := not rexpon(exponent_width-1);
        result (rexpon'range)              := float(rexpon);
        result (-1 downto -fraction_width) := float(rfract);
      else                              -- return zero
        result := zerofp (fraction_width => fraction_width,
                          exponent_width => exponent_width);
      end if;
    elsif (exp > expon_base-1) then     -- infinity
      result := pos_inffp (fraction_width => fraction_width,
                           exponent_width => exponent_width);
      result (exponent_width) := sign;  -- redo sign bit for neg inf.
    else                                -- normal number
      sfract := fract srl shiftr;       -- shift
      if nguard > 0 then
        round := check_round (
          fract_in    => sfract (nguard),
          sign        => sign,
          remainder   => sfract(nguard-1 downto 0),
          sticky      => sticky,
          round_style => round_style);
      end if;
      if round then
        fp_round(fract_in  => sfract (fraction_width-1+nguard downto nguard),
                 expon_in  => exp(rexp'range),
                 fract_out => rfract,
                 expon_out => rexp);
      else
        rfract := sfract (fraction_width-1+nguard downto nguard);
        rexp   := exp(rexp'range);
      end if;
      -- result
      rexpon                             := UNSIGNED (rexp(exponent_width-1 downto 0));
      rexpon(exponent_width-1)           := not rexpon(exponent_width-1);
      result (rexpon'range)              := float(rexpon);
      result (-1 downto -fraction_width) := float(rfract);
    end if;
    return result;
  end function normalize;

  -- purpose: normalizes a floating point number
  -- This version assumes a "ufixed" input with
  function normalize (
    fract                   : ufixed;   -- unsigned fixed point
    expon                   : SIGNED;   -- exponent, normalized by -1
    sign                    : STD_ULOGIC;                       -- sign bit
    sticky                  : STD_ULOGIC := '0';  -- Sticky bit (rounding)
    constant exponent_width : NATURAL    := float_exponent_width;  -- size of output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- size of output fraction
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant denormalize    : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant nguard         : NATURAL    := float_guard_bits)   -- guard bits
    return float is
    variable result : float (exponent_width downto -fraction_width);
    variable arguns : UNSIGNED (fract'high + fraction_width + nguard
                                downto 0) := (others => '0');
  begin  -- function normalize
    for i in arguns'high downto maximum (arguns'high-fract'length+1, 0) loop
      arguns (i) := fract (fract'high + (i-arguns'high));
    end loop;
    result := normalize (fract          => arguns,
                         expon          => expon,
                         sign           => sign,
                         sticky         => sticky,
                         fraction_width => fraction_width,
                         exponent_width => exponent_width,
                         round_style    => round_style,
                         denormalize    => denormalize,
                         nguard         => nguard);
    return result;
  end function normalize;

  -- purpose: normalizes a floating point number
  -- This version assumes a "ufixed" input with
  function normalize (
    fract                : ufixed;      -- unsigned fixed point
    expon                : SIGNED;      -- exponent, normalized by -1
    sign                 : STD_ULOGIC;  -- sign bit
    sticky               : STD_ULOGIC := '0';  -- Sticky bit (rounding)
    size_res             : float;       -- used for sizing only
    constant round_style : round_type := float_round_style;  -- rounding option
    constant denormalize : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant nguard      : NATURAL    := float_guard_bits)   -- guard bits
    return float is
    constant fraction_width : NATURAL := -size_res'low;
    constant exponent_width : NATURAL := size_res'high;
    variable result         : float (exponent_width downto -fraction_width);
    variable arguns : UNSIGNED (fract'high + fraction_width + nguard
                                downto 0) := (others => '0');
  begin  -- function normalize
    for i in arguns'high downto maximum (arguns'high-fract'length+1, 0) loop
      arguns (i) := fract (fract'high + (i-arguns'high));
    end loop;
    result := normalize (fract          => arguns,
                         expon          => expon,
                         sign           => sign,
                         sticky         => sticky,
                         fraction_width => fraction_width,
                         exponent_width => exponent_width,
                         round_style    => round_style,
                         denormalize    => denormalize,
                         nguard         => nguard);
    return result;
  end function normalize;

  function normalize (
    fract                : UNSIGNED;    -- unsigned
    expon                : SIGNED;      -- exponent - 1, normalized
    sign                 : STD_ULOGIC;  -- sign bit
    sticky               : STD_ULOGIC := '0';  -- Sticky bit (rounding)
    size_res             : float;       -- used for sizing only
    constant round_style : round_type := float_round_style;  -- rounding option
    constant denormalize : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant nguard      : NATURAL    := float_guard_bits)   -- guard bits
    return float is
  begin
    return normalize (fract          => fract,
                      expon          => expon,
                      sign           => sign,
                      sticky         => sticky,
                      fraction_width => -size_res'low,
                      exponent_width => size_res'high,
                      round_style    => round_style,
                      denormalize    => denormalize,
                      nguard         => nguard);
  end function normalize;
  -- Returns the class which X falls into
  -- Synthisable
  function Class (
    x           : float;                -- floating point input
    check_error : BOOLEAN := float_check_error)   -- check for errors
    return valid_fpstate is
    constant fraction_width : INTEGER := -minx(x'low, x'low);  -- length of FP output fraction
    constant exponent_width : INTEGER := x'high;  -- length of FP output exponent
    variable arg            : float (exponent_width downto -fraction_width);
  begin  -- class
    if (arg'length < 1 or fraction_width < 3 or exponent_width < 3
        or x'left < x'right) then
      report "FLOAT_GENERIC_PKG.CLASS: " &
        "Floating point number detected with a bad range"
        severity error;
      return isx;
    end if;
    -- Check for "X".
    arg := to_01 (x, 'X');
    if (arg(0) = 'X') then
      return isx;                       -- If there is an X in the number
      -- Special cases, check for illegal number
    elsif check_error and
      and_reducex (STD_LOGIC_VECTOR (arg (exponent_width-1 downto 0)))
       = '1' then                       -- Exponent is all "1".
      if or_reducex (to_slv (arg (-1 downto -fraction_width)))
         /= '0' then  -- Fraction must be all "0" or this is not a number.
        if (arg(-1) = '1') then         -- From "W. Khan - IEEE standard
          return nan;            -- 754 binary FP Signaling nan (Not a number)
        else
          return quiet_nan;
        end if;
        -- Check for infinity
      elsif arg(exponent_width) = '0' then
        return pos_inf;                 -- Positive infinity
      else
        return neg_inf;                 -- Negative infinity
      end if;
      -- check for "0"
    elsif or_reducex (STD_LOGIC_VECTOR (arg (exponent_width-1 downto 0)))
       = '0' then                       -- Exponent is all "0"
      if or_reducex (to_slv (arg(-1 downto -fraction_width)))
         = '0' then                     -- Fraction is all "0"
        if arg(exponent_width) = '0' then
          return pos_zero;              -- Zero
        else
          return neg_zero;
        end if;
      else
        if arg(exponent_width) = '0' then
          return pos_denormal;          -- Denormal number (ieee extended fp)
        else
          return neg_denormal;
        end if;
      end if;
    else
      if arg(exponent_width) = '0' then
        return pos_normal;              -- Normal FP number
      else
        return neg_normal;
      end if;
    end if;
  end function Class;

  procedure break_number (
    arg         : in  float;
    denormalize : in  BOOLEAN := float_denormalize;
    check_error : in  BOOLEAN := float_check_error;
    fract       : out UNSIGNED;
    expon       : out SIGNED;
    sign        : out STD_ULOGIC) is
    constant fraction_width : NATURAL                            := -minx(arg'low, arg'low);  -- length of FP output fraction
    constant exponent_width : NATURAL                            := arg'high;  -- length of FP output exponent
    constant expon_base     : SIGNED (exponent_width-1 downto 0) :=
      gen_expon_base(exponent_width);   -- exponent offset
    variable fptyp : valid_fpstate;
    variable exp   : SIGNED (expon'range);
  begin
    fptyp                             := Class (arg, check_error);
    fract (fraction_width-1 downto 0) :=
      UNSIGNED (to_slv(arg(-1 downto -fraction_width)));
    sign := to_x01(arg(arg'high));
    breakcase : case fptyp is
      when pos_zero | neg_zero =>
        fract (fraction_width) := '0';
        exp                    := -expon_base;
      when pos_denormal | neg_denormal =>
        if denormalize then
          exp                    := -expon_base;
          fract (fraction_width) := '0';
        else
          exp                    := -expon_base - 1;
          fract (fraction_width) := '1';
        end if;
      when pos_normal | neg_normal | pos_inf | neg_inf =>
        fract (fraction_width) := '1';
        exp                    := to_01(SIGNED(arg(exponent_width-1 downto 0)), 'X');
        exp (exponent_width-1) := not exp(exponent_width-1);
      when others =>
        assert NO_WARNING
          report "FLOAT_GENERIC_PKG.BREAK_NUMBER: " &
          "Meta state detected in fp_break_number process"
          severity warning;
        -- complete the case, if a meta state goes in, a meta state comes out.
        exp                    := (others => '1');
        fract (fraction_width) := '1';
    end case breakcase;
    expon := exp;
  end procedure break_number;
  
  procedure break_number (
    arg         : in  float;
    denormalize : in  BOOLEAN := float_denormalize;
    check_error : in  BOOLEAN := float_check_error;
    fract       : out ufixed;           -- 1 downto -fraction_width
    expon       : out SIGNED;           -- exponent_width-1 downto 0
    sign        : out STD_ULOGIC) is
    constant fraction_width : NATURAL                            := -minx(arg'low, arg'low);  -- length of FP output fraction
    constant exponent_width : NATURAL                            := arg'high;  -- length of FP output exponent
    constant expon_base     : SIGNED (exponent_width-1 downto 0) :=
      gen_expon_base(exponent_width);   -- exponent offset
    variable fptyp : valid_fpstate;
    variable exp   : SIGNED (expon'range);
  begin
    fptyp := Class (arg, check_error);
    for i in -1 downto -fraction_width loop
      fract(i) := arg(i);
    end loop;
    sign := to_x01(arg(arg'high));
    breakcase : case fptyp is
      when pos_zero | neg_zero =>
        fract (0) := '0';
        exp       := -expon_base;
      when pos_denormal | neg_denormal =>
        if denormalize then
          exp       := -expon_base;
          fract (0) := '0';
        else
          exp       := -expon_base - 1;
          fract (0) := '1';
        end if;
      when pos_normal | neg_normal | pos_inf | neg_inf =>
        fract (0)              := '1';
        exp                    := to_01(SIGNED(arg(exponent_width-1 downto 0)), 'X');
        exp (exponent_width-1) := not exp(exponent_width-1);
      when others =>
        assert NO_WARNING
          report "FLOAT_GENERIC_PKG.BREAK_NUMBER: " &
          "Meta state detected in fp_break_number process"
          severity warning;
        -- complete the case, if a meta state goes in, a meta state comes out.
        exp       := (others => '1');
        fract (0) := '1';
    end case breakcase;
    expon := exp;
  end procedure break_number;

  -- Arithmetic functions
  -- Synthisable
  function "abs" (
    arg : float)                          -- floating point input
    return float is
    variable result : float (arg'range);  -- result
  begin
    if (arg'length > 0) then
      result            := to_01 (arg, 'X');
      result (arg'high) := '0';           -- set the sign bit to positive     
      return result;
    else
      return NAFP;
    end if;
  end function "abs";

  -- IEEE 754 "negative" function
  -- Synthisable
  function "-" (
    arg : float)                                   -- floating point input
    return float is
    variable result : float (arg'range);           -- result
  begin
    if (arg'length > 0) then
      result            := to_01 (arg, 'X');
      result (arg'high) := not result (arg'high);  -- invert sign bit
      return result;
    else
      return NAFP;
    end if;
  end function "-";

  -- Synthisable
  function add (
    l, r                 : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    constant fraction_width   : NATURAL := -minx(l'low, r'low);  -- length of FP output fraction
    constant exponent_width   : NATURAL := maximum(l'high, r'high);  -- length of FP output exponent
    constant addguard         : NATURAL := guard;         -- add one guard bit
    variable lfptype, rfptype : valid_fpstate;
    variable fpresult         : float (exponent_width downto -fraction_width);
    variable fractl, fractr   : UNSIGNED(fraction_width+1+addguard downto 0);  -- fractions
    variable fractc, fracts   : UNSIGNED (fractl'range);  -- constant and shifted variables
    variable urfract, ulfract : UNSIGNED (fraction_width downto 0);
    variable ufract           : UNSIGNED (fraction_width+1+addguard downto 0);
    variable exponl, exponr   : SIGNED(exponent_width-1 downto 0);  -- exponents
    variable rexpon           : SIGNED(exponent_width downto 0);  -- result exponent
    variable shiftx           : SIGNED(exponent_width downto 0);  -- shift fractions
    variable sign             : STD_ULOGIC;               -- sign of the output
    variable leftright        : BOOLEAN;  -- left or right used
    variable lresize, rresize : float (exponent_width downto -fraction_width);
    variable sticky           : STD_ULOGIC;   -- Holds precision for rounding
  begin  -- addition
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      lfptype := isx;
    else
      lfptype := class (l, check_error);
      rfptype := class (r, check_error);
    end if;
    if (lfptype = isx or rfptype = isx) then
      fpresult := (others => 'X');
    elsif (lfptype = nan or lfptype = quiet_nan or
           rfptype = nan or rfptype = quiet_nan)
      -- Return quiet NAN, IEEE754-1985-7.1,1
      or (lfptype = pos_inf and rfptype = neg_inf)
      or (lfptype = neg_inf and rfptype = pos_inf) then
      -- Return quiet NAN, IEEE754-1985-7.1,2
      fpresult := qnanfp (fraction_width => fraction_width,
                          exponent_width => exponent_width);
    elsif (lfptype = pos_inf or rfptype = pos_inf) then   -- x + inf = inf
      fpresult := pos_inffp (fraction_width => fraction_width,
                             exponent_width => exponent_width);
    elsif (lfptype = neg_inf or rfptype = neg_inf) then   -- x - inf = -inf
      fpresult := neg_inffp (fraction_width => fraction_width,
                             exponent_width => exponent_width);
    else
      lresize := resize (arg            => l,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      lfptype := class (lresize, false);  -- errors already checked
      rresize := resize (arg            => r,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      rfptype := class (rresize, false);  -- errors already checked
      break_number (
        arg         => lresize,
        fptyp       => lfptype,
        denormalize => denormalize,
        fract       => ulfract,
        expon       => exponl);
      fractl                                           := (others => '0');
      fractl (fraction_width+addguard downto addguard) := ulfract;
      break_number (
        arg         => rresize,
        fptyp       => rfptype,
        denormalize => denormalize,
        fract       => urfract,
        expon       => exponr);
      fractr := (others => '0');
      fractr (fraction_width+addguard downto addguard) := urfract;
      shiftx := (exponl(exponent_width-1) & exponl) - exponr;
      if shiftx < -fractl'high then
        rexpon    := exponr(exponent_width-1) & exponr;
        fractc    := fractr;
        fracts    := (others => '0');   -- add zero
        leftright := false;
        sticky    := or_reducex (fractl);
      elsif shiftx < 0 then
        shiftx    := - shiftx;
        fracts    := shift_right (fractl, to_integer(shiftx));
        fractc    := fractr;
        rexpon    := exponr(exponent_width-1) & exponr;
        leftright := false;
--        sticky    := or_reducex (fractl (to_integer(shiftx) downto 0));
        sticky    := smallfract (fractl, to_integer(shiftx));
      elsif shiftx = 0 then
        rexpon := exponl(exponent_width-1) & exponl;
        sticky := '0';
        if fractr > fractl then
          fractc    := fractr;
          fracts    := fractl;
          leftright := false;
        else
          fractc    := fractl;
          fracts    := fractr;
          leftright := true;
        end if;
      elsif shiftx > fractr'high then
        rexpon    := exponl(exponent_width-1) & exponl;
        fracts    := (others => '0');   -- add zero
        fractc    := fractl;
        leftright := true;
        sticky    := or_reducex (fractr);
      elsif shiftx > 0 then
        fracts    := shift_right (fractr, to_integer(shiftx));
        fractc    := fractl;
        rexpon    := exponl(exponent_width-1) & exponl;
        leftright := true;
--        sticky    := or_reducex (fractr (to_integer(shiftx) downto 0));
        sticky    := smallfract (fractr, to_integer(shiftx));
      end if;
      -- add
      fracts (0) := fracts (0) or sticky;  -- Or the sticky bit into the LSB
      if l(l'high) = r(r'high) then
        ufract := fractc + fracts;
        sign   := l(l'high);
      else                              -- signs are different
        ufract := fractc - fracts;      -- always positive result
        if leftright then               -- Figure out which sign to use
          sign := l(l'high);
        else
          sign := r(r'high);
        end if;
      end if;
      -- normalize
      fpresult := normalize (fract          => ufract,
                             expon          => rexpon,
                             sign           => sign,
                             sticky         => sticky,
                             fraction_width => fraction_width,
                             exponent_width => exponent_width,
                             round_style    => round_style,
                             denormalize    => denormalize,
                             nguard         => addguard);
    end if;
    return fpresult;
  end function add;

  -- Calls "add".
  -- Synthisable
  function subtract (
    l, r                 : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    variable negr : float (r'range);    -- negative version of r
  begin
    negr := -r;                         -- r := -r
    return add (l           => l,
                r           => negr,
                round_style => round_style,
                guard       => guard,
                check_error => check_error,
                denormalize => denormalize);
  end function subtract;
  
  function multiply (
    l, r                 : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    constant fraction_width   : NATURAL := -minx(l'low, r'low);  -- length of FP output fraction
    constant exponent_width   : NATURAL := maximum(l'high, r'high);  -- length of FP output exponent
    constant multguard        : NATURAL := guard;           -- guard bits
    variable lfptype, rfptype : valid_fpstate;
    variable fpresult         : float (exponent_width downto -fraction_width);
    variable fractl, fractr   : UNSIGNED(fraction_width downto 0);  -- fractions
    variable rfract           : UNSIGNED((2*(fraction_width))+1 downto 0);  -- result fraction
    variable sfract           : UNSIGNED(fraction_width+1+multguard downto 0);  -- result fraction
    variable exponl, exponr   : SIGNED(exponent_width-1 downto 0);  -- exponents
    variable rexpon           : SIGNED(exponent_width downto 0);  -- result exponent
    variable fp_sign          : STD_ULOGIC;                 -- sign of result
    variable lresize, rresize : float (exponent_width downto -fraction_width);
    variable sticky           : STD_ULOGIC;   -- Holds precision for rounding
  begin  -- multiply
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      lfptype := isx;
    else
      lfptype := class (l, check_error);
      rfptype := class (r, check_error);
    end if;
    if (lfptype = isx or rfptype = isx) then
      fpresult := (others => 'X');
    elsif ((lfptype = nan or lfptype = quiet_nan or
            rfptype = nan or rfptype = quiet_nan)) then
      -- Return quiet NAN, IEEE754-1985-7.1,1
      fpresult := qnanfp (fraction_width => fraction_width,
                          exponent_width => exponent_width);
    elsif (((lfptype = pos_inf or lfptype = neg_inf) and
            (rfptype = pos_zero or rfptype = neg_zero)) or
           ((rfptype = pos_inf or rfptype = neg_inf) and
            (lfptype = pos_zero or lfptype = neg_zero))) then    -- 0 * inf
      -- Return quiet NAN, IEEE754-1985-7.1,3
      fpresult := qnanfp (fraction_width => fraction_width,
                          exponent_width => exponent_width);
    elsif (lfptype = pos_inf or rfptype = pos_inf
           or lfptype = neg_inf or rfptype = neg_inf) then  -- x * inf = inf
      fpresult := pos_inffp (fraction_width => fraction_width,
                             exponent_width => exponent_width);
      -- figure out the sign
      fpresult (exponent_width) := l(l'high) xor r(r'high);
    else
      fp_sign := l(l'high) xor r(r'high);  -- figure out the sign
      lresize := resize (arg            => l,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      lfptype := class (lresize, false);   -- errors already checked
      rresize := resize (arg            => r,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      rfptype := class (rresize, false);   -- errors already checked
      break_number (
        arg         => lresize,
        fptyp       => lfptype,
        denormalize => denormalize,
        fract       => fractl,
        expon       => exponl);
      break_number (
        arg         => rresize,
        fptyp       => rfptype,
        denormalize => denormalize,
        fract       => fractr,
        expon       => exponr);
      -- multiply
      rfract := fractl * fractr;        -- Multiply the fraction
      sfract := rfract (rfract'high downto
                        rfract'high - (fraction_width+1+multguard));
      sticky := or_reducex(rfract (rfract'high-(fraction_width+1+multguard)
                                   downto 0));
      -- add the exponents
      rexpon := (exponl(exponl'high)&exponl) + (exponr(exponr'high)&exponr) +1;
      -- normalize
      fpresult := normalize (fract          => sfract,
                             expon          => rexpon,
                             sign           => fp_sign,
                             sticky         => sticky,
                             fraction_width => fraction_width,
                             exponent_width => exponent_width,
                             round_style    => round_style,
                             denormalize    => denormalize,
                             nguard         => multguard);
    end if;
    return fpresult;
  end function multiply;

  function short_divide (
    lx, rx : UNSIGNED)
    return UNSIGNED is
    -- This is a special divider for the floating point routies.
    -- For a true unsigned divider, "stages" needs to = lx'high
    constant stages       : INTEGER := lx'high - rx'high;  -- number of stages
    variable partial      : UNSIGNED (lx'range);
    variable q            : UNSIGNED (stages downto 0);
    variable partial_argl : SIGNED (rx'high + 2 downto 0);
    variable partial_arg  : SIGNED (rx'high + 2 downto 0);
  begin
    partial := lx;
    for i in stages downto 0 loop
      partial_argl := resize ("0" & SIGNED (partial(lx'high downto i)),
                              partial_argl'length);
      partial_arg := partial_argl - SIGNED ("0" & rx);
      if (partial_arg (partial_arg'high) = '1') then       -- negative
        q(i) := '0';
      else
        q(i)                                                       := '1';
        partial (lx'high+i-stages downto lx'high+i-stages-rx'high) :=
          UNSIGNED (partial_arg(rx'range));
      end if;
    end loop;
    -- to make the output look like that of the unsigned IEEE divide.
    return resize (q, lx'length);
  end function short_divide;

  -- 1/X function.  Needed for algorithm development.
  function reciprocal (
    arg                  : float;
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    constant fraction_width : NATURAL := -minx(arg'low, arg'low);  -- length of FP output fraction
    constant exponent_width : NATURAL := arg'high;  -- length of FP output exponent
    constant divguard       : NATURAL := guard;     -- guard bits
    function onedivy (
      arg : UNSIGNED)
      return UNSIGNED is
      variable q   : UNSIGNED((2*arg'high)+1 downto 0);
      variable one : UNSIGNED (q'range);
    begin
      one           := (others => '0');
      one(one'high) := '1';
      q             := short_divide (one, arg);     -- Unsiged divide
      return resize (q, arg'length+1);
    end function onedivy;
    variable fptype        : valid_fpstate;
    variable expon         : SIGNED(exponent_width-1 downto 0);    -- exponents
    variable denorm_offset : NATURAL range 0 to 2;
    variable fract         : UNSIGNED(fraction_width downto 0);
    variable fractg        : UNSIGNED(fraction_width+divguard downto 0);
    variable sfract        : UNSIGNED(fraction_width+1+divguard downto 0);  -- result fraction
    variable fpresult      : float (exponent_width downto -fraction_width);
  begin  -- reciprocal
    fptype := class(arg, check_error);
    classcase : case fptype is
      when isx =>
        fpresult := (others => 'X');
      when nan | quiet_nan =>
        -- Return quiet NAN, IEEE754-1985-7.1,1
        fpresult := qnanfp (fraction_width => fraction_width,
                            exponent_width => exponent_width);
      when pos_inf | neg_inf =>         -- 1/inf, return 0
        fpresult := zerofp (fraction_width => fraction_width,
                            exponent_width => exponent_width);
      when neg_zero | pos_zero =>       -- 1/0
        report "FLOAT_GENERIC_PKG.RECIPROCAL: Floating Point divide by zero"
          severity error;
        fpresult := pos_inffp (fraction_width => fraction_width,
                               exponent_width => exponent_width);
      when others =>
        if (fptype = pos_denormal or fptype = neg_denormal)
          and ((arg (-1) or arg(-2)) /= '1') then
          -- 1/denormal = infinity, with the exception of 2**-expon_base
          fpresult := pos_inffp (fraction_width => fraction_width,
                                 exponent_width => exponent_width);
          fpresult (exponent_width) := to_x01 (arg (exponent_width));
        else
          break_number (
            arg         => arg,
            fptyp       => fptype,
            denormalize => denormalize,
            fract       => fract,
            expon       => expon);
          fractg := (others => '0');
          if (fptype = pos_denormal or fptype = neg_denormal) then
            -- The reciprocal of a denormal number is typically zero,
            -- execpt for two special cases which are trapped here.
            if (to_x01(arg (-1)) = '1') then
              fractg (fractg'high downto divguard+1) :=
                fract (fract'high-1 downto 0);      -- Shift to not denormal
              denorm_offset := 1;       -- add 1 to exponent compensate
            else                        -- arg(-2) = '1'
              fractg (fractg'high downto divguard+2) :=
                fract (fract'high-2 downto 0);      -- Shift to not denormal
              denorm_offset := 2;       -- add 2 to exponent compensate
            end if;
          else
            fractg (fractg'high downto divguard) := fract;
            denorm_offset                        := 0;
          end if;
          expon  := - expon - 3 + denorm_offset;
          sfract := onedivy (fractg);
          -- normalize
          fpresult := normalize (fract          => sfract,
                                 expon          => expon,
                                 sign           => arg(exponent_width),
                                 sticky         => '1',
                                 fraction_width => fraction_width,
                                 exponent_width => exponent_width,
                                 round_style    => round_style,
                                 denormalize    => denormalize,
                                 nguard         => divguard);
        end if;
    end case classcase;
    return fpresult;
  end function reciprocal;

  -- Synthisable
  function divide (
    l, r                 : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    constant fraction_width   : NATURAL := -minx(l'low, r'low);  -- length of FP output fraction
    constant exponent_width   : NATURAL := maximum(l'high, r'high);  -- length of FP output exponent
    constant divguard         : NATURAL := guard;  -- division guard bits
    variable lfptype, rfptype : valid_fpstate;
    variable fpresult         : float (exponent_width downto -fraction_width);
    variable ulfract, urfract : UNSIGNED (fraction_width downto 0);
--    variable fractl           : unsigned((2*(fraction_width+1)+divguard+2) downto 0);  -- left
    variable fractl           : UNSIGNED((2*(fraction_width+divguard)+1) downto 0);  -- left
    variable fractr           : UNSIGNED(fraction_width+divguard downto 0);  -- right
    variable rfract           : UNSIGNED(fractl'range);     -- result fraction
    variable sfract           : UNSIGNED(fraction_width+1+divguard downto 0);  -- result fraction
    variable exponl, exponr   : SIGNED(exponent_width-1 downto 0);  -- exponents
    variable rexpon           : SIGNED(exponent_width downto 0);  -- result exponent
    variable fp_sign          : STD_ULOGIC;        -- sign of result
    variable shifty           : INTEGER;           -- denormal number shift
    variable lresize, rresize : float (exponent_width downto -fraction_width);
  begin  -- divide
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      lfptype := isx;
    else
      lfptype := class (l, check_error);
      rfptype := class (r, check_error);
    end if;
    classcase : case rfptype is
      when isx =>
        fpresult := (others => 'X');
      when nan | quiet_nan =>
        -- Return quiet NAN, IEEE754-1985-7.1,1
        fpresult := qnanfp (fraction_width => fraction_width,
                            exponent_width => exponent_width);
      when pos_inf | neg_inf =>
        if lfptype = pos_inf or lfptype = neg_inf  -- inf / inf
          or lfptype = quiet_nan or lfptype = nan then
          -- Return quiet NAN, IEEE754-1985-7.1,4
          fpresult := qnanfp (fraction_width => fraction_width,
                              exponent_width => exponent_width);
        else                            -- x / inf = 0
          fpresult := zerofp (fraction_width => fraction_width,
                              exponent_width => exponent_width);
        end if;
      when pos_zero | neg_zero =>
        if lfptype = pos_zero or lfptype = neg_zero         -- 0 / 0
          or lfptype = quiet_nan or lfptype = nan then
          -- Return quiet NAN, IEEE754-1985-7.1,4
          fpresult := qnanfp (fraction_width => fraction_width,
                              exponent_width => exponent_width);
        else
          report "FLOAT_GENERIC_PKG.DIVIDE: Floating Point divide by zero"
            severity error;
          -- Infinity, define in 754-1985-7.2
          fpresult := pos_inffp (fraction_width => fraction_width,
                                 exponent_width => exponent_width);
        end if;
      when others =>
        fp_sign := l(l'high) xor r(r'high);        -- sign
        classcase2 : case lfptype is
          when isx =>
            fpresult := (others => 'X');
          when nan | quiet_nan =>
            -- Return quiet NAN, IEEE754-1985-7.1,1
            fpresult := qnanfp (fraction_width => fraction_width,
                                exponent_width => exponent_width);
          when pos_inf | neg_inf =>     -- inf / x = inf
            fpresult := pos_inffp (fraction_width => fraction_width,
                                   exponent_width => exponent_width);
            fpresult(exponent_width) := fp_sign;
          when pos_zero | neg_zero =>   -- 0 / X = 0
            fpresult := zerofp (fraction_width => fraction_width,
                                exponent_width => exponent_width);
          when others =>
            lresize := resize (arg            => l,
                               exponent_width => exponent_width,
                               fraction_width => fraction_width,
                               denormalize_in => denormalize,
                               denormalize    => denormalize);
            lfptype := class (lresize, false);     -- errors already checked
            rresize := resize (arg            => r,
                               exponent_width => exponent_width,
                               fraction_width => fraction_width,
                               denormalize_in => denormalize,
                               denormalize    => denormalize);
            rfptype := class (rresize, false);     -- errors already checked
            fractl  := (others => '0');
            break_number (
              arg         => lresize,
              fptyp       => lfptype,
              denormalize => denormalize,
              fract       => ulfract,
              expon       => exponl);
            fractl (fractl'high downto fractl'high-fraction_width) := ulfract;
            -- right side
            fractr                                                 := (others => '0');
            break_number (
              arg         => rresize,
              fptyp       => rfptype,
              denormalize => denormalize,
              fract       => urfract,
              expon       => exponr);
            fractr (fraction_width+divguard downto divguard) := urfract;
            rexpon                                           := (exponl(exponl'high)&exponl)
                                                                - (exponr(exponr'high)&exponr) - 2;
            if (rfptype = pos_denormal or rfptype = neg_denormal) then
              -- Do the shifting here not after.  That way we have a smaller
              -- shifter, and need a smaller divider, because the top
              -- bit in the divisor will always be a "1".
              shifty := fraction_width - find_msb(urfract, '1');
              fractr := shift_left (fractr, shifty);
              rexpon := rexpon + shifty;
            end if;
            -- divide
            rfract := short_divide (fractl, fractr);        -- unsigned divide
            sfract := rfract (sfract'range);       -- lower bits
            -- normalize
            fpresult := normalize (fract          => sfract,
                                   expon          => rexpon,
                                   sign           => fp_sign,
                                   sticky         => '1',
                                   fraction_width => fraction_width,
                                   exponent_width => exponent_width,
                                   round_style    => round_style,
                                   denormalize    => denormalize,
                                   nguard         => divguard);
        end case classcase2;
    end case classcase;
    return fpresult;
  end function divide;

  -- division by a power of 2
  function dividebyp2 (
    l, r                 : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    constant fraction_width   : NATURAL := -minx(l'low, r'low);  -- length of FP output fraction
    constant exponent_width   : NATURAL := maximum(l'high, r'high);  -- length of FP output exponent
    variable lfptype, rfptype : valid_fpstate;
    variable fpresult         : float (exponent_width downto -fraction_width);
    variable ulfract, urfract : UNSIGNED (fraction_width downto 0);
    variable exponl, exponr   : SIGNED(exponent_width-1 downto 0);  -- exponents
    variable rexpon           : SIGNED(exponent_width downto 0);  -- result exponent
    variable fp_sign          : STD_ULOGIC;     -- sign of result
    variable lresize, rresize : float (exponent_width downto -fraction_width);
  begin  -- divisionbyp2
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      lfptype := isx;
    else
      lfptype := class (l, check_error);
      rfptype := class (r, check_error);
    end if;
    classcase : case rfptype is
      when isx =>
        fpresult := (others => 'X');
      when nan | quiet_nan =>
        -- Return quiet NAN, IEEE754-1985-7.1,1
        fpresult := qnanfp (fraction_width => fraction_width,
                            exponent_width => exponent_width);
      when pos_inf | neg_inf =>
        if lfptype = pos_inf or lfptype = neg_inf then      -- inf / inf
          -- Return quiet NAN, IEEE754-1985-7.1,4
          fpresult := qnanfp (fraction_width => fraction_width,
                              exponent_width => exponent_width);
        else                            -- x / inf = 0
          fpresult := zerofp (fraction_width => fraction_width,
                              exponent_width => exponent_width);
        end if;
      when pos_zero | neg_zero =>
        if lfptype = pos_zero or lfptype = neg_zero then    -- 0 / 0
          -- Return quiet NAN, IEEE754-1985-7.1,4
          fpresult := qnanfp (fraction_width => fraction_width,
                              exponent_width => exponent_width);
        else
          report "FLOAT_GENERIC_PKG.DIVIDEBYP2: Floating Point divide by zero"
            severity error;
          -- Infinity, define in 754-1985-7.2
          fpresult := pos_inffp (fraction_width => fraction_width,
                                 exponent_width => exponent_width);
        end if;
      when others =>
        classcase2 : case lfptype is
          when isx =>
            fpresult := (others => 'X');
          when nan | quiet_nan =>
            -- Return quiet NAN, IEEE754-1985-7.1,1
            fpresult := qnanfp (fraction_width => fraction_width,
                                exponent_width => exponent_width);
          when pos_inf | neg_inf =>     -- inf / x = inf
            fpresult := pos_inffp (fraction_width => fraction_width,
                                   exponent_width => exponent_width);
            fpresult(exponent_width) := l(exponent_width) xor r(exponent_width);
          when pos_zero | neg_zero =>   -- 0 / X = 0
            fpresult := zerofp (fraction_width => fraction_width,
                                exponent_width => exponent_width);
          when others =>
            lresize := resize (arg            => l,
                               exponent_width => exponent_width,
                               fraction_width => fraction_width,
                               denormalize_in => denormalize,
                               denormalize    => denormalize);
            lfptype := class (lresize, false);  -- errors already checked
            rresize := resize (arg            => r,
                               exponent_width => exponent_width,
                               fraction_width => fraction_width,
                               denormalize_in => denormalize,
                               denormalize    => denormalize);
            rfptype := class (rresize, false);  -- errors already checked
            fp_sign := l(l'high) xor r(r'high);             -- sign
            break_number (
              arg         => lresize,
              fptyp       => lfptype,
              denormalize => denormalize,
              fract       => ulfract,
              expon       => exponl);
            -- right side
            break_number (
              arg         => rresize,
              fptyp       => rfptype,
              denormalize => denormalize,
              fract       => urfract,
              expon       => exponr);
            assert (or_reducex (urfract (fraction_width-1 downto 0)) = '0')
              report "FLOAT_GENERIC_PKG.DIVIDEBYP2: "
              & "Divideby2 called with a none power of two denominator"
              severity error;
            rexpon := (exponl(exponl'high)&exponl)
                      - (exponr(exponr'high)&exponr) - 1;
            -- normalize
            fpresult := normalize (fract          => ulfract,
                                   expon          => rexpon,
                                   sign           => fp_sign,
                                   sticky         => '1',
                                   fraction_width => fraction_width,
                                   exponent_width => exponent_width,
                                   round_style    => round_style,
                                   denormalize    => denormalize,
                                   nguard         => 0);
        end case classcase2;
    end case classcase;
    return fpresult;
  end function dividebyp2;

-- Multiply accumumlate  result = l*r + c
  function mac (
    l, r, c              : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    constant fraction_width : NATURAL :=
      -minx (minx(l'low, r'low), c'low);  -- length of FP output fraction
    constant exponent_width : NATURAL :=
      maximum (maximum(l'high, r'high), c'high);  -- length of FP output exponent
    variable lfptype, rfptype, cfptype : valid_fpstate;
    variable fpresult                  : float (exponent_width downto -fraction_width);
    variable fractl, fractr            : UNSIGNED(fraction_width downto 0);  -- fractions
    variable fractx                    : UNSIGNED (fraction_width+guard downto 0);
    variable fractc, fracts            : UNSIGNED (fraction_width+1+guard downto 0);
    variable rfract                    : UNSIGNED((2*(fraction_width))+1 downto 0);  -- result fraction
    variable sfract, ufract            : UNSIGNED(fraction_width+1+guard downto 0);  -- result fraction
    variable exponl, exponr, exponc    : SIGNED(exponent_width-1 downto 0);  -- exponents
    variable shiftx                    : SIGNED(exponent_width downto 0);  -- shift fractions
    variable rexpon, rexpon2           : SIGNED(exponent_width downto 0);  -- result exponent
    variable fp_sign                   : STD_ULOGIC;  -- sign of result
    variable lresize, rresize          : float (exponent_width downto -fraction_width);
    variable cresize                   : float (exponent_width downto -fraction_width - guard);
    variable leftright                 : BOOLEAN;     -- left or right used
    variable sticky                    : STD_ULOGIC;  -- Holds precision for rounding
  begin  -- multiply
    if (fraction_width = 0 or l'length < 7 or r'length < 7 or c'length < 7) then
      lfptype := isx;
    else
      lfptype := class (l, check_error);
      rfptype := class (r, check_error);
      cfptype := class (c, check_error);
    end if;
    if (lfptype = isx or rfptype = isx or cfptype = isx) then
      fpresult := (others => 'X');
    elsif (lfptype = nan or lfptype = quiet_nan or
           rfptype = nan or rfptype = quiet_nan or
           cfptype = nan or cfptype = quiet_nan) then
      -- Return quiet NAN, IEEE754-1985-7.1,1
      fpresult := qnanfp (fraction_width => fraction_width,
                          exponent_width => exponent_width);
    elsif (((lfptype = pos_inf or lfptype = neg_inf) and
            (rfptype = pos_zero or rfptype = neg_zero)) or
           ((rfptype = pos_inf or rfptype = neg_inf) and
            (lfptype = pos_zero or lfptype = neg_zero))) then  -- 0 * inf
      -- Return quiet NAN, IEEE754-1985-7.1,3
      fpresult := qnanfp (fraction_width => fraction_width,
                          exponent_width => exponent_width);
    elsif (lfptype = pos_inf or rfptype = pos_inf
           or lfptype = neg_inf or rfptype = neg_inf  -- x * inf = inf
           or cfptype = neg_inf or cfptype = pos_inf) then  -- x + inf = inf
      fpresult := pos_inffp (fraction_width => fraction_width,
                             exponent_width => exponent_width);
      -- figure out the sign
      fpresult (exponent_width) := l(l'high) xor r(r'high);
    else
      fp_sign := l(l'high) xor r(r'high);         -- figure out the sign
      lresize := resize (arg            => l,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      lfptype := class (lresize, false);  -- errors already checked
      rresize := resize (arg            => r,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      rfptype := class (rresize, false);  -- errors already checked
      cresize := resize (arg            => c,
                         exponent_width => exponent_width,
                         fraction_width => -cresize'low,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      cfptype := class (cresize, false);  -- errors already checked
      break_number (
        arg         => lresize,
        fptyp       => lfptype,
        denormalize => denormalize,
        fract       => fractl,
        expon       => exponl);
      break_number (
        arg         => rresize,
        fptyp       => rfptype,
        denormalize => denormalize,
        fract       => fractr,
        expon       => exponr);
      break_number (
        arg         => cresize,
        fptyp       => cfptype,
        denormalize => denormalize,
        fract       => fractx,
        expon       => exponc);

      -- multiply
      rfract := fractl * fractr;           -- Multiply the fraction
      -- add the exponents
      rexpon := (exponl(exponl'high)&exponl) + (exponr(exponr'high)&exponr) +1;
      shiftx := rexpon - exponc;
      if shiftx < -fractl'high then
        rexpon2 := exponc(exponent_width-1) & exponc;
        fractc  := "0" & fractx;
        fracts  := (others => '0');
        sticky  := or_reducex (rfract);
      elsif shiftx < 0 then
        shiftx := - shiftx;
        fracts := shift_right (rfract (rfract'high downto rfract'high
                                       - fracts'length+1),
                               to_integer(shiftx));
        fractc    := "0" & fractx;
        rexpon2   := exponc(exponent_width-1) & exponc;
        leftright := false;
        sticky := or_reducex (rfract (to_integer(shiftx)+rfract'high
                                      - fracts'length downto 0));
      elsif shiftx = 0 then
        rexpon2 := exponc(exponent_width-1) & exponc;
        sticky  := or_reducex (rfract (rfract'high - fractc'length downto 0));
        if rfract (rfract'high downto rfract'high - fractc'length+1) > fractx
        then
          fractc := "0" & fractx;
          fracts := rfract (rfract'high downto rfract'high
                            - fracts'length+1);
          leftright := false;
        else
          fractc := rfract (rfract'high downto rfract'high
                            - fractc'length+1);
          fracts    := "0" & fractx;
          leftright := true;
        end if;
      elsif shiftx > fractx'high then
        rexpon2   := rexpon;
        fracts    := (others => '0');
        fractc    := rfract (rfract'high downto rfract'high - fractc'length+1);
        leftright := true;
        sticky := or_reducex (fractx & rfract (rfract'high - fractc'length
                                               downto 0));
      else                                 -- fractx'high > shiftx > 0
        rexpon2   := rexpon;
        fracts    := "0" & shift_right (fractx, to_integer (shiftx));
        fractc    := rfract (rfract'high downto rfract'high - fractc'length+1);
        leftright := true;
        sticky := or_reducex (fractx (to_integer (shiftx) downto 0)
                              & rfract (rfract'high - fractc'length downto 0));
      end if;
      fracts (0) := fracts (0) or sticky;  -- Or the sticky bit into the LSB
      if fp_sign = to_X01(c(c'high)) then
        ufract  := fractc + fracts;
        fp_sign := fp_sign;
      else                                 -- signs are different
        ufract := fractc - fracts;         -- always positive result
        if leftright then                  -- Figure out which sign to use
          fp_sign := fp_sign;
        else
          fp_sign := c(c'high);
        end if;
      end if;
      -- normalize
      fpresult := normalize (fract          => ufract,
                             expon          => rexpon2,
                             sign           => fp_sign,
                             sticky         => sticky,
                             fraction_width => fraction_width,
                             exponent_width => exponent_width,
                             round_style    => round_style,
                             denormalize    => denormalize,
                             nguard         => guard);
    end if;
    return fpresult;
  end function mac;

  function remainder (
    l, r                 : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    constant fraction_width   : NATURAL := -minx(l'low, r'low);  -- length of FP output fraction
    constant exponent_width   : NATURAL := maximum(l'high, r'high);  -- length of FP output exponent
    constant divguard         : NATURAL := guard;  -- division guard bits
    variable lfptype, rfptype : valid_fpstate;
    variable fpresult         : float (exponent_width downto -fraction_width);
    variable ulfract, urfract : UNSIGNED (fraction_width downto 0);
    variable fractr, fractl   : UNSIGNED(fraction_width+divguard downto 0);  -- right
    variable rfract           : UNSIGNED(fractr'range);     -- result fraction
    variable sfract           : UNSIGNED(fraction_width+divguard downto 0);  -- result fraction
    variable exponl, exponr   : SIGNED(exponent_width-1 downto 0);  -- exponents
    variable rexpon           : SIGNED(exponent_width downto 0);  -- result exponent
    variable fp_sign          : STD_ULOGIC;        -- sign of result
    variable shifty           : INTEGER;           -- denormal number shift
    variable lresize, rresize : float (exponent_width downto -fraction_width);
  begin  -- remainder
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      lfptype := isx;
    else
      lfptype := class (l, check_error);
      rfptype := class (r, check_error);
    end if;
    if (lfptype = isx or rfptype = isx) then
      fpresult := (others => 'X');
    elsif (lfptype = nan or lfptype = quiet_nan)
      or (rfptype = nan or rfptype = quiet_nan)
      -- Return quiet NAN, IEEE754-1985-7.1,1
      or (lfptype = pos_inf or lfptype = neg_inf)  -- inf rem x
      -- Return quiet NAN, IEEE754-1985-7.1,5
      or (rfptype = pos_zero or rfptype = neg_zero) then    -- x rem 0
      -- Return quiet NAN, IEEE754-1985-7.1,5
      fpresult := qnanfp (fraction_width => fraction_width,
                          exponent_width => exponent_width);
    elsif (rfptype = pos_inf or rfptype = neg_inf) then     -- x rem inf = 0
      fpresult := zerofp (fraction_width => fraction_width,
                          exponent_width => exponent_width);
    elsif (abs(l) < abs(r)) then
      fpresult := l;
    else
      fp_sign := to_X01(l(l'high));             -- sign
      lresize := resize (arg            => l,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      lfptype := class (lresize, false);           -- errors already checked
      rresize := resize (arg            => r,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      rfptype := class (rresize, false);           -- errors already checked
      fractl  := (others => '0');
      break_number (
        arg         => lresize,
        fptyp       => lfptype,
        denormalize => denormalize,
        fract       => ulfract,
        expon       => exponl);
      fractl (fraction_width+divguard downto divguard) := ulfract;
      -- right side
      fractr                                           := (others => '0');
      break_number (
        arg         => rresize,
        fptyp       => rfptype,
        denormalize => denormalize,
        fract       => urfract,
        expon       => exponr);
      fractr (fraction_width+divguard downto divguard) := urfract;
      rexpon                                           := (exponr(exponr'high)&exponr);
      shifty                                           := to_integer(exponl - rexpon);
      if (shifty > 0) then
        fractr := shift_right (fractr, shifty);
        rexpon := rexpon + shifty;
      end if;
      if (fractr /= 0) then
        -- rem
        rfract := fractl rem fractr;    -- unsigned rem
        sfract := rfract (sfract'range);           -- lower bits
        -- normalize
        fpresult := normalize (fract          => sfract,
                               expon          => rexpon,
                               sign           => fp_sign,
                               fraction_width => fraction_width,
                               exponent_width => exponent_width,
                               round_style    => round_style,
                               denormalize    => denormalize,
                               nguard         => divguard);
      else
        -- If we shift "fractr" so far that it becomes zero, return zero.
        fpresult := zerofp (fraction_width => fraction_width,
                            exponent_width => exponent_width);
      end if;
    end if;
    return fpresult;
  end function remainder;
  
  function modulo (
    l, r                 : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant guard       : NATURAL    := float_guard_bits;  -- number of guard bits
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    constant fraction_width : NATURAL := - minx(l'low, r'low);  -- length of FP output fraction
    constant exponent_width : NATURAL := maximum(l'high, r'high);  -- length of FP output exponent
    variable lfptype, rfptype : valid_fpstate;
    variable fpresult         : float (exponent_width downto -fraction_width);
    variable remres           : float (exponent_width downto -fraction_width);
  begin  -- remainder
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      lfptype := isx;
    else
      lfptype := class (l, check_error);
      rfptype := class (r, check_error);
    end if;
    if (lfptype = isx or rfptype = isx) then
      fpresult := (others => 'X');
    elsif (lfptype = nan or lfptype = quiet_nan)
      or (rfptype = nan or rfptype = quiet_nan)
      -- Return quiet NAN, IEEE754-1985-7.1,1
      or (lfptype = pos_inf or lfptype = neg_inf)           -- inf rem x
      -- Return quiet NAN, IEEE754-1985-7.1,5
      or (rfptype = pos_zero or rfptype = neg_zero) then    -- x rem 0
      -- Return quiet NAN, IEEE754-1985-7.1,5
      fpresult := qnanfp (fraction_width => fraction_width,
                          exponent_width => exponent_width);
    elsif (rfptype = pos_inf or rfptype = neg_inf) then     -- x rem inf = 0
      fpresult := zerofp (fraction_width => fraction_width,
                          exponent_width => exponent_width);
    else
      remres := remainder (l           => abs(l),
                           r           => abs(r),
                           round_style => round_style,
                           guard       => guard,
                           check_error => false,
                           denormalize => denormalize);
      -- MOD is the same as REM, but you do something different with
      -- negative values
      if (is_negative (l)) then
        remres := - remres;
      end if;
      if (is_negative (l) = is_negative (r) or remres = 0) then
        fpresult := remres;
      else
        fpresult := add (l           => remres,
                         r           => r,
                         round_style => round_style,
                         guard       => guard,
                         check_error => false,
                         denormalize => denormalize);        
      end if;
    end if;
    return fpresult;
  end function modulo;

  function Is_Negative (arg : float) return BOOLEAN is
  begin
    return (to_x01(arg(arg'high)) = '1');
  end function Is_Negative;

  -- compare functions
  -- =, /=, >=, <=, <, >

  -- Synthisable
  function eq (                         -- equal =
    l, r                 : float;       -- floating point input
    constant check_error : BOOLEAN := float_check_error;
    constant denormalize : BOOLEAN := float_denormalize)
    return BOOLEAN is
    variable lfptype, rfptype       : valid_fpstate;
    variable is_equal, is_unordered : BOOLEAN;
    constant fraction_width         : NATURAL := -minx(l'low, r'low);  -- length of FP output fraction
    constant exponent_width         : NATURAL := maximum(l'high, r'high);  -- length of FP output exponent
    variable lresize, rresize       : float (exponent_width downto -fraction_width);
  begin  -- equal
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      return false;
    else
      lfptype := class (l, check_error);
      rfptype := class (r, check_error);
    end if;
    if (lfptype = neg_zero or lfptype = pos_zero) and
      (rfptype = neg_zero or rfptype = pos_zero) then
      is_equal := true;
    else
      lresize := resize (arg            => l,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      rresize := resize (arg            => r,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      is_equal := (to_slv(lresize) = to_slv(rresize));
    end if;
    if (check_error) then
      is_unordered := Unordered (x => l,
                                 y => r);
    else
      is_unordered := false;
    end if;
    return is_equal and not is_unordered;
  end function eq;

  -- Synthisable
  function lt (                         -- less than <
    l, r                 : float;       -- floating point input
    constant check_error : BOOLEAN := float_check_error;
    constant denormalize : BOOLEAN := float_denormalize)
    return BOOLEAN is
    constant fraction_width             : NATURAL := -minx(l'low, r'low);  -- length of FP output fraction
    constant exponent_width             : NATURAL := maximum(l'high, r'high);  -- length of FP output exponent
    variable lfptype, rfptype           : valid_fpstate;
    variable expl, expr                 : UNSIGNED (exponent_width-1 downto 0);
    variable fractl, fractr             : UNSIGNED (fraction_width-1 downto 0);
    variable is_less_than, is_unordered : BOOLEAN;
    variable lresize, rresize           : float (exponent_width downto -fraction_width);
  begin
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      is_less_than := false;
    else
      lresize := resize (arg            => l,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      rresize := resize (arg            => r,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      if to_x01(l(l'high)) = to_x01(r(r'high)) then  -- sign bits
        expl := to_01(UNSIGNED(lresize(exponent_width-1 downto 0)), 'X');
        expr := to_01(UNSIGNED(rresize(exponent_width-1 downto 0)), 'X');
        if expl = expr then
          fractl := UNSIGNED (to_slv(lresize(-1 downto -fraction_width)));
          fractr := UNSIGNED (to_slv(rresize(-1 downto -fraction_width)));
          if to_x01(l(l'high)) = '0' then            -- positive number
            is_less_than := (fractl < fractr);
          else
            is_less_than := (fractl > fractr);       -- negative
          end if;
        else
          if to_x01(l(l'high)) = '0' then            -- positive number
            is_less_than := (expl < expr);
          else
            is_less_than := (expl > expr);           -- negative
          end if;
        end if;
      else
        lfptype := class (l, check_error);
        rfptype := class (r, check_error);
        if (lfptype = neg_zero and rfptype = pos_zero) then
          is_less_than := false;        -- -0 < 0 returns false.
        else
          is_less_than := (to_x01(l(l'high)) > to_x01(r(r'high)));
        end if;
      end if;
    end if;
    if check_error then
      is_unordered := Unordered (x => l,
                                 y => r);
    else
      is_unordered := false;
    end if;
    return is_less_than and not is_unordered;
  end function lt;

  -- Synthisable
  function gt (                         -- greater than >
    l, r                 : float;       -- floating point input
    constant check_error : BOOLEAN := float_check_error;
    constant denormalize : BOOLEAN := float_denormalize)
    return BOOLEAN is
    constant fraction_width   : NATURAL := -minx(l'low, r'low);  -- length of FP output fraction
    constant exponent_width   : NATURAL := maximum(l'high, r'high);  -- length of FP output exponent
    variable lfptype, rfptype : valid_fpstate;
    variable expl, expr       : UNSIGNED (exponent_width-1 downto 0);
    variable fractl, fractr   : UNSIGNED (fraction_width-1 downto 0);
    variable is_greater_than  : BOOLEAN;
    variable is_unordered     : BOOLEAN;
    variable lresize, rresize : float (exponent_width downto -fraction_width);
  begin  -- greater_than
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      is_greater_than := false;
    else
      lresize := resize (arg            => l,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      rresize := resize (arg            => r,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => denormalize,
                         denormalize    => denormalize);
      if to_x01(l(l'high)) = to_x01(r(r'high)) then              -- sign bits
        expl := to_01(UNSIGNED(lresize(exponent_width-1 downto 0)), 'X');
        expr := to_01(UNSIGNED(rresize(exponent_width-1 downto 0)), 'X');
        if expl = expr then
          fractl := UNSIGNED (to_slv(lresize(-1 downto -fraction_width)));
          fractr := UNSIGNED (to_slv(rresize(-1 downto -fraction_width)));
          if to_x01(l(l'high)) = '0' then  -- positive number
            is_greater_than := fractl > fractr;
          else
            is_greater_than := fractl < fractr;                  -- negative
          end if;
        else
          if to_x01(l(l'high)) = '0' then  -- positive number
            is_greater_than := expl > expr;
          else
            is_greater_than := expl < expr;                      -- negative
          end if;
        end if;
      else
        lfptype := class (l, check_error);
        rfptype := class (r, check_error);
        if (lfptype = pos_zero and rfptype = neg_zero) then
          is_greater_than := false;     -- 0 > -0 returns false.
        else
          is_greater_than := to_x01(l(l'high)) < to_x01(r(r'high));
        end if;
      end if;
    end if;
    if check_error then
      is_unordered := Unordered (x => l,
                                 y => r);
    else
      is_unordered := false;
    end if;
    return is_greater_than and not is_unordered;
  end function gt;

  -- purpose: /= function
  function ne (                         -- not equal /=
    l, r                 : float;
    constant check_error : BOOLEAN := float_check_error;
    constant denormalize : BOOLEAN := float_denormalize)
    return BOOLEAN is
    variable is_equal, is_unordered : BOOLEAN;
  begin
    is_equal := eq (l           => l,
                    r           => r,
                    check_error => false,
                    denormalize => denormalize);
    if check_error then
      is_unordered := Unordered (x => l,
                                 y => r);
    else
      is_unordered := false;
    end if;
    return not (is_equal and not is_unordered);
  end function ne;

  function le (                         -- less than or equal to <=
    l, r                 : float;       -- floating point input
    constant check_error : BOOLEAN := float_check_error;
    constant denormalize : BOOLEAN := float_denormalize)
    return BOOLEAN is
    variable is_greater_than, is_unordered : BOOLEAN;
  begin
    is_greater_than := gt (l           => l,
                           r           => r,
                           check_error => false,
                           denormalize => denormalize);
    if check_error then
      is_unordered := Unordered (x => l,
                                 y => r);
    else
      is_unordered := false;
    end if;
    return not is_greater_than and not is_unordered;
  end function le;

  function ge (                         -- greather than or equal to >=
    l, r                 : float;       -- floating point input
    constant check_error : BOOLEAN := float_check_error;
    constant denormalize : BOOLEAN := float_denormalize)
    return BOOLEAN is
    variable is_less_than, is_unordered : BOOLEAN;
  begin
    is_less_than := lt (l           => l,
                        r           => r,
                        check_error => false,
                        denormalize => denormalize);
    if check_error then
      is_unordered := Unordered (x => l,
                                 y => r);
    else
      is_unordered := false;
    end if;
    return not is_less_than and not is_unordered;
  end function ge;

  --%%% Uncomment the following function
--  function "?=" (L, R: float) return std_ulogic is
  function \?=\ (L, R : float) return STD_ULOGIC is
    constant fraction_width         : NATURAL := -minx(l'low, r'low);  -- length of FP output fraction
    constant exponent_width         : NATURAL := maximum(l'high, r'high);  -- length of FP output exponent
    variable lresize, rresize       : float (exponent_width downto -fraction_width);
  begin  -- ?=
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      return 'X';
    else
      lresize := resize (arg            => l,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => float_denormalize,
                         denormalize    => float_denormalize);
      rresize := resize (arg            => r,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => float_denormalize,
                         denormalize    => float_denormalize);
      return \?=\ (ufixed(lresize), ufixed(rresize));
  --%%%    return (to_slv(lresize) ?= to_slv(rresize));
    end if;
  end function \?=\;
  --%%% end function "?=";

  function \?/=\ (L, R : float) return STD_ULOGIC is
    constant fraction_width         : NATURAL := -minx(l'low, r'low);  -- length of FP output fraction
    constant exponent_width         : NATURAL := maximum(l'high, r'high);  -- length of FP output exponent
    variable lresize, rresize       : float (exponent_width downto -fraction_width);
  begin  -- ?/=
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      return 'X';
    else
      lresize := resize (arg            => l,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => float_denormalize,
                         denormalize    => float_denormalize);
      rresize := resize (arg            => r,
                         exponent_width => exponent_width,
                         fraction_width => fraction_width,
                         denormalize_in => float_denormalize,
                         denormalize    => float_denormalize);
      return \?/=\ (ufixed(lresize), ufixed(rresize));
  --%%%    return (to_slv(lresize) ?/= to_slv(rresize));
    end if;
  end function \?/=\;
  --%%% end function "?/=";

  -- %%% function "?>" (L, R : float) return std_ulogic is
  function \?>\ (L, R : float) return std_ulogic is
    constant fraction_width         : NATURAL := -minx(l'low, r'low);
  begin
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      return 'X';
    elsif (find_msb (l, '-') /= l'low-1)
      or (find_msb (r, '-') /= r'low-1) then
      report "float_generic_pkg.""?>"": '-' found in compare string"
        severity error;
      return 'X';
    else
      if is_x(l) or is_x(r) then
        return 'X';
      elsif l > r then
        return '1';
      else
        return '0';
      end if;
    end if;
  end function \?>\;
  -- %%% end function "?>";

  -- %%% function "?>=" (L, R : float) return std_ulogic is
  function \?>=\ (L, R : float) return std_ulogic is
    constant fraction_width         : NATURAL := -minx(l'low, r'low);
  begin
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      return 'X';
    elsif (find_msb (l, '-') /= l'low-1)
      or (find_msb (r, '-') /= r'low-1) then
      report "float_generic_pkg.""?>="": '-' found in compare string"
        severity error;
      return 'X';
    else
      if is_x(l) or is_x(r) then
        return 'X';
      elsif l >= r then
        return '1';
      else
        return '0';
      end if;
    end if;
  end function \?>=\;
  -- %%% end function "?>=";

  -- %%% function "?<" (L, R : float) return std_ulogic is
  function \?<\ (L, R : float) return std_ulogic is
    constant fraction_width         : NATURAL := -minx(l'low, r'low);
  begin
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      return 'X';
    elsif (find_msb (l, '-') /= l'low-1)
      or (find_msb (r, '-') /= r'low-1) then
      report "float_generic_pkg.""?<"": '-' found in compare string"
        severity error;
      return 'X';
    else
      if is_x(l) or is_x(r) then
        return 'X';
      elsif l < r then
        return '1';
      else
        return '0';
      end if;
    end if;
  end function \?<\;
  -- %%% end function "?<";

  -- %%% function "?<=" (L, R : float) return std_ulogic is
  function \?<=\ (L, R : float) return std_ulogic is
    constant fraction_width         : NATURAL := -minx(l'low, r'low);
  begin
    if (fraction_width = 0 or l'length < 7 or r'length < 7) then
      return 'X';
    elsif (find_msb (l, '-') /= l'low-1)
      or (find_msb (r, '-') /= r'low-1) then
      report "float_generic_pkg.""?<="": '-' found in compare string"
        severity error;
      return 'X';
    else
      if is_x(l) or is_x(r) then
        return 'X';
      elsif l <= r then
        return '1';
      else
        return '0';
      end if;
    end if;
  end function \?<=\;
  -- %%% end function "?<=";

  function std_match (L, R : float) return BOOLEAN is
  begin
    return std_match(to_slv(L), to_slv(R));
  end function std_match;

  function find_lsb (arg : float; y : STD_ULOGIC) return INTEGER is
  begin
    for_loop : for i in arg'low to arg'high loop
      if arg(i) = y then
        return i;
      end if;
    end loop;
    return arg'high+1;                  -- return out of bounds 'high
  end function find_lsb;

  function find_msb (arg : float; y : STD_ULOGIC) return INTEGER is
  begin
    for_loop : for i in arg'high downto arg'low loop
      if arg(i) = y then
        return i;
      end if;
    end loop;
    return arg'low-1;                   -- return out of bounds 'low
  end function find_msb;

  -- These override the defaults for the compare operators.
  function "=" (l, r : float) return BOOLEAN is
  begin
    return eq(l, r);
  end function "=";
  function "/=" (l, r : float) return BOOLEAN is
  begin
    return ne(l, r);
  end function "/=";
  function ">=" (l, r : float) return BOOLEAN is
  begin
    return ge(l, r);
  end function ">=";
  function "<=" (l, r : float) return BOOLEAN is
  begin
    return le(l, r);
  end function "<=";
  function ">" (l, r : float) return BOOLEAN is
  begin
    return gt(l, r);
  end function ">";
  function "<" (l, r : float) return BOOLEAN is
  begin
    return lt(l, r);
  end function "<";
  -- purpose: maximum of two numbers (overrides default)
  function maximum (
    L, R : float)
    return float is
  begin
    if l > r then return l;
    else return r;
    end if;
  end function maximum;

  function minimum (
    L, R : float)
    return float is
  begin
    if l > r then return r;
    else return l;
    end if;
  end function minimum;

  -----------------------------------------------------------------------------
  -- conversion functions
  -----------------------------------------------------------------------------

  -- Converts a floating point number of one format into another format
  -- Synthesizable
  function resize (
    arg                     : float;    -- Floating point input
    constant exponent_width : NATURAL    := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- length of FP output fraction
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant check_error    : BOOLEAN    := float_check_error;
    constant denormalize_in : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant denormalize    : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    constant in_fraction_width : NATURAL := -arg'low;  -- length of FP output fraction
    constant in_exponent_width : NATURAL := arg'high;  -- length of FP output exponent
    variable result            : float (exponent_width downto -fraction_width);
                                        -- result value
    variable fptype            : valid_fpstate;
    variable expon_in          : SIGNED (in_exponent_width-1 downto 0);
    variable fract_in          : UNSIGNED (in_fraction_width downto 0);
    variable round             : BOOLEAN;
    variable expon_out         : SIGNED (exponent_width-1 downto 0);  -- output fract
    variable fract_out         : UNSIGNED (fraction_width downto 0);  -- output fract
    variable passguard : NATURAL;
  begin
    fptype := class(arg, check_error);
    if ((fptype = pos_denormal or fptype = neg_denormal) and denormalize_in
        and (in_exponent_width < exponent_width
             or in_fraction_width < fraction_width))
      or in_exponent_width > exponent_width
      or in_fraction_width > fraction_width then
      -- size reduction
      classcase : case fptype is
        when isx =>
          result := (others => 'X');
        when nan | quiet_nan =>
          result := qnanfp (fraction_width => fraction_width,
                            exponent_width => exponent_width);
        when pos_inf =>
          result := pos_inffp (fraction_width => fraction_width,
                               exponent_width => exponent_width);
        when neg_inf =>
          result := neg_inffp (fraction_width => fraction_width,
                               exponent_width => exponent_width);
        when pos_zero | neg_zero =>
          result := zerofp (fraction_width => fraction_width,     -- hate -0
                            exponent_width => exponent_width);
        when others =>
          break_number (
            arg         => arg,
            fptyp       => fptype,
            denormalize => denormalize_in,
            fract       => fract_in,
            expon       => expon_in);
          if fraction_width > in_fraction_width and denormalize_in then
            -- You only get here if you have a denormal input
            fract_out := (others => '0');                -- pad with zeros
            fract_out (fraction_width downto
                       fraction_width - in_fraction_width) := fract_in;
            result := normalize (
              fract          => fract_out,
              expon          => expon_in,
              sign           => arg(arg'high),
              fraction_width => fraction_width,
              exponent_width => exponent_width,
              round_style    => round_style,
              denormalize    => denormalize,
              nguard         => 0);
          else
            result := normalize (
              fract          => fract_in,
              expon          => expon_in,
              sign           => arg(arg'high),
              fraction_width => fraction_width,
              exponent_width => exponent_width,
              round_style    => round_style,
              denormalize    => denormalize,
              nguard         => in_fraction_width - fraction_width);
          end if;
      end case classcase;
    else      -- size increase or the same size
      if exponent_width > in_exponent_width then
        expon_in := signed(arg (in_exponent_width-1 downto 0));
        if fptype = pos_zero or fptype = neg_zero then
          result (exponent_width-1 downto 0) := (others => '0');
        elsif expon_in = -1 then        -- inf or nan (shorts out check_error)
          result (exponent_width-1 downto 0) := (others => '1');
        else
          -- invert top BIT
          expon_in(expon_in'high) := not expon_in(expon_in'high);
          expon_out := resize (expon_in, expon_out'length);  -- signed expand
          -- Flip it back.
          expon_out(expon_out'high) := not expon_out(expon_out'high);
          result (exponent_width-1 downto 0) := float(expon_out);
        end if;
        result (exponent_width) := arg (in_exponent_width);  -- sign
      else        -- exponent_width = in_exponent_width
        result (exponent_width downto 0) := arg (in_exponent_width downto 0);
      end if;
      if fraction_width > in_fraction_width then
        result (-1 downto -fraction_width) := (others => '0'); -- zeros
        result (-1 downto -in_fraction_width) :=
          arg (-1 downto -in_fraction_width);
      else                              -- fraction_width = in_fraciton_width
        result (-1 downto -fraction_width) :=
          arg (-1 downto -in_fraction_width);
      end if;
    end if;
    return result;
  end function resize;

  function resize (
    arg                     : float;    -- Floating point input
    size_res                : float;
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant check_error    : BOOLEAN    := float_check_error;
    constant denormalize_in : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant denormalize    : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    variable result : float (size_res'left downto size_res'right);
  begin
    if (result'length < 1) then
      return result;
    else
      result := resize (arg            => arg,
                        fraction_width => -size_res'low,
                        exponent_width => size_res'high,
                        round_style    => round_style,
                        check_error    => check_error,
                        denormalize_in => denormalize_in,
                        denormalize    => denormalize);
      return result;
    end if;
  end function resize;

  function to_float32 (
    arg                     : float;
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant check_error    : BOOLEAN    := float_check_error;
    constant denormalize_in : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant denormalize    : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
  begin
    return resize (arg            => arg,
                   exponent_width => float32'high,
                   fraction_width => -float32'low,
                   round_style    => round_style,
                   check_error    => check_error,
                   denormalize_in => denormalize_in,
                   denormalize    => denormalize);
  end function to_float32;

  function to_float64 (
    arg                     : float;
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant check_error    : BOOLEAN    := float_check_error;
    constant denormalize_in : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant denormalize    : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
  begin
    return resize (arg            => arg,
                   exponent_width => float64'high,
                   fraction_width => -float64'low,
                   round_style    => round_style,
                   check_error    => check_error,
                   denormalize_in => denormalize_in,
                   denormalize    => denormalize);
  end function to_float64;

  function to_float128 (
    arg                     : float;
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant check_error    : BOOLEAN    := float_check_error;
    constant denormalize_in : BOOLEAN    := float_denormalize;  -- Use IEEE extended FP
    constant denormalize    : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
  begin
    return resize (arg            => arg,
                   exponent_width => float128'high,
                   fraction_width => -float128'low,
                   round_style    => round_style,
                   check_error    => check_error,
                   denormalize_in => denormalize_in,
                   denormalize    => denormalize);
  end function to_float128;
  
  -- to_float (Real)
  -- Not Synthisable (unless the input is a constant)
  function to_float (
    arg                     : REAL;
    constant exponent_width : NATURAL    := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- length of FP output fraction
    constant round_style    : round_type := float_round_style;  -- rounding option
    constant denormalize    : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    variable result     : float (exponent_width downto -fraction_width);
    variable arg_real   : REAL;         -- Real version of argument
    variable validfp    : boundary_type;  -- Check for valid results
    variable exp        : INTEGER;      -- Integer version of exponent
    variable exp_real   : REAL;         -- real version of exponent
    variable expon      : UNSIGNED (exponent_width - 1 downto 0);
                                        -- Unsigned version of exp.
    constant expon_base : SIGNED (exponent_width-1 downto 0) :=
      gen_expon_base(exponent_width);   -- exponent offset
    variable fract     : UNSIGNED (fraction_width-1 downto 0);
    variable frac      : REAL;          -- Real version of fraction
    constant roundfrac : REAL := 2.0 ** (-2 - fract'high);  -- used for rounding
    variable round     : BOOLEAN;       -- to round or not to round
  begin
    result   := (others => '0');
    arg_real := arg;
    if arg_real < 0.0 then
      result (exponent_width) := '1';
      arg_real                := 0.0 - arg_real;            -- Make it positive.
    else
      result (exponent_width) := '0';
    end if;
    validfp := test_boundary (arg            => arg_real,
                              fraction_width => fraction_width,
                              exponent_width => exponent_width,
                              denormalize    => denormalize);
    if validfp = zero then
      return result;                    -- Result initialized to "0".
    elsif validfp = infinity then
      result (exponent_width - 1 downto 0) := (others => '1');  -- Exponent all "1"
                                        -- return infinity.
      return result;
    else
      if validfp = denormal then        -- Exponent will default to "0".
        expon := (others => '0');
        frac  := arg_real * (2.0 ** (to_integer(expon_base)-1));
      else                              -- Number less than 1. "normal" number
--        exp_real                := log (arg_real)/ log (2.0);
        exp_real                := log2 (arg_real);
        exp                     := INTEGER (floor(exp_real));  -- positive fraction.
        expon                   := UNSIGNED (to_signed (exp-1, exponent_width));
        expon(exponent_width-1) := not expon(exponent_width-1);
        frac                    := (arg_real / 2.0 ** exp) - 1.0;  -- Number less than 1.
      end if;
      for i in 0 to fract'high loop
        if frac >= 2.0 ** (-1 - i) then
          fract (fract'high - i) := '1';
          frac                   := frac - 2.0 ** (-1 - i);
        else
          fract (fract'high - i) := '0';
        end if;
      end loop;
      round := false;
      case round_style is
        when round_nearest =>
          if frac > roundfrac or ((frac = roundfrac) and fract(0) = '1') then
            round := true;
          end if;
        when round_inf =>
          if frac /= 0.0 and result(exponent_width) = '0' then
            round := true;
          end if;
        when round_neginf =>
          if frac /= 0.0 and result(exponent_width) = '1' then
            round := true;
          end if;
        when round_zero =>
          null;                         -- don't round
      end case;
      if (round) then
        if and_reducex(fract) = '1' then  -- fraction is all "1"
          expon := expon + 1;
          fract := (others => '0');
        else
          fract := fract + 1;
        end if;
      end if;
      result (exponent_width-1 downto 0) := float(expon);
      result (-1 downto -fraction_width) := float(fract);
      return result;
    end if;
  end function to_float;

  -- to_float (Integer)
  -- Synthisable
  function to_float (
    arg                     : INTEGER;
    constant exponent_width : NATURAL    := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- length of FP output fraction
    constant round_style    : round_type := float_round_style)  -- rounding option
    return float is
    variable result      : float (exponent_width downto -fraction_width);
    variable arg_int     : INTEGER;     -- Real version of argument
    variable rexp        : SIGNED (exponent_width - 1 downto 0);
    variable exp         : SIGNED (exponent_width - 1 downto 0);
    -- signed version of exp.
    variable expon       : UNSIGNED (exponent_width - 1 downto 0);
    -- Unsigned version of exp.
    variable rfract      : UNSIGNED (fraction_width-1 downto 0);
    variable fract       : UNSIGNED (fraction_width-1 downto 0);
    variable round       : BOOLEAN;
    constant frac_base   : INTEGER := 30;  -- Base to multiply fraction by
    variable fract_shift : UNSIGNED (frac_base downto 0);
    -- unshifted fract
    variable validfp     : boundary_type;  -- used to check integer
  begin
    if arg < 0 then
      result (exponent_width) := '1';
      arg_int                 := -arg;  -- Make it positive.
    else
      result (exponent_width) := '0';
      arg_int                 := arg;
    end if;
    validfp := fp_input_type (arg            => arg_int,
                              exponent_width => exponent_width,
                              fraction_width => fraction_width);
    if validfp = zero then
      result := zerofp (fraction_width => fraction_width,
                        exponent_width => exponent_width);
    elsif validfp = infinity then
      if result (exponent_width) = '0' then
        result := pos_inffp (fraction_width => fraction_width,
                             exponent_width => exponent_width);
      else
        -- return infinity.
        result := neg_inffp (fraction_width => fraction_width,
                             exponent_width => exponent_width);
      end if;
    else                                -- Normal number (can't be denormal)
      -- Compute Exponent
      exp         := to_signed (log2(arg_int), exp'length);  -- positive fraction.
      -- Compute Fraction
      fract_shift := to_unsigned (arg_int, frac_base+1);
      fract_shift := shift_left (fract_shift, (frac_base-to_integer(exp)));
      -- pull out the fraction
      fract       := (others => '0');  -- zero out fraction first.
      fract (fract'high downto maximum(0, fract'high-(frac_base-1))) :=
        fract_shift (frac_base-1 downto maximum(0, frac_base-1-fract'high));
      -- Round
      if frac_base-1-fract'high > 0 then
        round := check_round (
          fract_in    => fract (0),
          sign        => result (exponent_width),
          remainder   => fract_shift (frac_base-2-fract'high
                                      downto 0),
          round_style => round_style);
        if round then
          fp_round(fract_in  => fract,
                   expon_in  => exp,
                   fract_out => rfract,
                   expon_out => rexp);
        else
          rfract := fract;
          rexp   := exp;
        end if;
      else
        rexp   := exp;
        rfract := fract;
      end if;
      expon                              := UNSIGNED (rexp-1);
      expon(exponent_width-1)            := not expon(exponent_width-1);
      result (exponent_width-1 downto 0) := float(expon);
      result (-1 downto -fraction_width) := float(rfract);
    end if;
    return result;
  end function to_float;

  -- to_float (unsigned)
  -- Synthesizable
  function to_float (
    arg                     : UNSIGNED;
    constant exponent_width : NATURAL    := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- length of FP output fraction
    constant round_style    : round_type := float_round_style)  -- rounding option
    return float is
    variable result     : float (exponent_width downto -fraction_width);
    constant ARG_LEFT   : INTEGER                            := ARG'length-1;
    alias XARG          : UNSIGNED(ARG_LEFT downto 0) is ARG;
    variable arg_int    : UNSIGNED(xarg'range);  -- Real version of argument
    variable argb2      : UNSIGNED(xarg'high/2 downto 0);       -- log2 of input
    variable rexp       : SIGNED (exponent_width - 1 downto 0);
    variable exp        : SIGNED (exponent_width - 1 downto 0);
    -- signed version of exp.
    variable expon      : UNSIGNED (exponent_width - 1 downto 0);
    -- Unsigned version of exp.
    constant expon_base : SIGNED (exponent_width-1 downto 0) :=
      gen_expon_base(exponent_width);   -- exponent offset
    variable round  : BOOLEAN;
    variable fract  : UNSIGNED (fraction_width-1 downto 0);
    variable rfract : UNSIGNED (fraction_width-1 downto 0);
  begin
    arg_int := UNSIGNED(to_x01(STD_LOGIC_VECTOR (xarg)));
    if (or_reducex (arg_int) = 'X') then
      result := (others => 'X');
    elsif (arg_int = 0) then
      result := zerofp (fraction_width => fraction_width,
                        exponent_width => exponent_width);
    else                                -- Normal number (can't be denormal)
      result (exponent_width) := '0';   -- positive sign
      -- Compute Exponent
      argb2                   := to_unsigned(find_msb(arg_int, '1'), argb2'length);  -- Log2
      if argb2 > UNSIGNED(expon_base) then
        result := pos_inffp (fraction_width => fraction_width,
                             exponent_width => exponent_width);
      else
        exp     := SIGNED(resize(argb2, exp'length));
        arg_int := shift_left (arg_int, arg_int'high-to_integer(exp));
        if (arg_int'high > fraction_width) then
          fract := arg_int (arg_int'high-1 downto (arg_int'high-fraction_width));
          round := check_round (
            fract_in    => fract (0),
            sign        => result (exponent_width),
            remainder   => arg_int((arg_int'high-fraction_width-1)
                                   downto 0),
            round_style => round_style);
          if round then
            fp_round(fract_in  => fract,
                     expon_in  => exp,
                     fract_out => rfract,
                     expon_out => rexp);
          else
            rfract := fract;
            rexp   := exp;
          end if;
        else
          rexp   := exp;
          rfract := (others => '0');
          rfract (fraction_width-1 downto fraction_width-1-(arg_int'high-1)) :=
            arg_int (arg_int'high-1 downto 0);
        end if;
        expon                              := UNSIGNED (rexp-1);
        expon(exponent_width-1)            := not expon(exponent_width-1);
        result (exponent_width-1 downto 0) := float(expon);
        result (-1 downto -fraction_width) := float(rfract);
      end if;
    end if;
    return result;
  end function to_float;

  -- to_float (signed)
  -- Synthesizable
  function to_float (
    arg                     : SIGNED;
    constant exponent_width : NATURAL    := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- length of FP output fraction
    constant round_style    : round_type := float_round_style)  -- rounding option
    return float is
    constant ARG_LEFT : INTEGER := ARG'length-1;
    alias XARG        : SIGNED(ARG_LEFT downto 0) is ARG;
    variable result   : float (exponent_width downto -fraction_width);
    variable argabs   : SIGNED (xarg'range);
    variable arg_int  : UNSIGNED(xarg'range);  -- unsigned version of argument
    variable sign     : STD_ULOGIC;     -- sign of the signed number
  begin
    sign    := to_x01 (xarg(xarg'high));
    argabs  := abs (xarg);
    arg_int := UNSIGNED (argabs);
    result := to_float (
      arg            => arg_int,
      fraction_width => fraction_width,
      exponent_width => exponent_width,
      round_style    => round_style);
    if sign = '1' then
      result (exponent_width) := '1';
    end if;
    return result;
  end function to_float;

  -- std_logic_vector to float
  function to_float (
    arg                     : STD_LOGIC_VECTOR;
    constant exponent_width : NATURAL := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- length of FP output fraction
    return float is
    variable fpvar : float (exponent_width downto -fraction_width);
    alias argslv   : STD_LOGIC_VECTOR (fpvar'length-1 downto 0) is arg;
  begin
    fpvar := float(argslv);
--    floop : for i in fpvar'range loop
--      fpvar(i) := to_X01 (argslv(i-fpvar'low));  -- fpvar(8) := arg (8+23)
--    end loop floop;
    return fpvar;
  end function to_float;

  -- std_ulogic_vector to float
  function to_float (
    arg                     : STD_ULOGIC_VECTOR;
    constant exponent_width : NATURAL := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- length of FP output fraction
    return float is
  begin
    return to_float (arg => to_stdlogicvector(arg),
                     exponent_width => exponent_width,
                     fraction_width => fraction_width);
  end function to_float;

  -- purpose: converts a ufixed to a floating point
  function to_float (
    arg                     : ufixed;   -- unsigned fixed point input
    constant exponent_width : NATURAL    := float_exponent_width;  -- width of exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- width of fraction
    constant round_style    : round_type := float_round_style;  -- rounding
    constant denormalize    : BOOLEAN    := float_denormalize)  -- use ieee extentions
    return float is
    constant integer_width     : INTEGER := arg'high;
    constant in_fraction_width : INTEGER := arg'low;
    variable xresult           : ufixed (integer_width downto in_fraction_width);
    variable result            : float (exponent_width downto -fraction_width);
    variable arg_int : UNSIGNED(integer_width - in_fraction_width
                                downto 0);          -- Real version of argument
    variable exp, exptmp : SIGNED (exponent_width downto 0);
    variable expon       : UNSIGNED (exponent_width - 1 downto 0);  -- Unsigned version of exp.
    constant expon_base  : SIGNED (exponent_width-1 downto 0) :=
      gen_expon_base(exponent_width);   -- exponent offset
    variable fract, fracttmp : UNSIGNED (fraction_width-1 downto 0) :=
      (others => '0');
    variable round : BOOLEAN := false;
  begin  -- function to_float
    xresult := to_01(arg, 'X');
    arg_int := UNSIGNED(to_slv(xresult));
    if (or_reducex (arg_int) = 'X') then
      result := (others => 'X');
    elsif (arg_int = 0) then
      result := (others => '0');        -- return zero
    else
      result := (others => '0');        -- positive sign
      -- Compute Exponent
      exp    := to_signed(find_msb(arg_int, '1'), exp'length);  -- Log2
      if exp + in_fraction_width > expon_base then  -- return infinity
        result := pos_inffp (fraction_width => fraction_width,
                             exponent_width => exponent_width);
        return result;
      elsif (denormalize and
             (exp + in_fraction_width <= -resize(expon_base, exp'length))) then
        -- denormal number
        exp := -resize(expon_base, exp'length);
        -- shift by a constant
        arg_int := shift_left (arg_int,
                               (arg_int'high + to_integer(expon_base)
                                + in_fraction_width - 1));
        if (arg_int'high > fraction_width) then
          fract := arg_int (arg_int'high-1 downto (arg_int'high-fraction_width));
          round := check_round (
            fract_in    => arg_int(arg_int'high-fraction_width),
            sign        => '0',
            remainder   => arg_int((arg_int'high-fraction_width-1)
                                   downto 0),
            round_style => round_style);
          if (round) then
            fp_round (fract_in => arg_int (arg_int'high-1 downto
                                           (arg_int'high-fraction_width)),
                      expon_in  => exp,
                      fract_out => fract,
                      expon_out => exptmp);
            exp := exptmp;
          end if;
        else
          fract (fraction_width-1 downto fraction_width-1-(arg_int'high-1)) :=
            arg_int (arg_int'high-1 downto 0);
        end if;
      else
        arg_int := shift_left (arg_int, arg_int'high-to_integer(exp));
        exp     := exp + in_fraction_width;
        if (arg_int'high > fraction_width) then
          fract := arg_int (arg_int'high-1 downto (arg_int'high-fraction_width));
          round := check_round (
            fract_in    => fract(0),
            sign        => '0',
            remainder   => arg_int((arg_int'high-fraction_width-1)
                                   downto 0),
            round_style => round_style);
          if (round) then
            fp_round (fract_in  => fract,
                      expon_in  => exp,
                      fract_out => fracttmp,
                      expon_out => exptmp);
            fract := fracttmp;
            exp   := exptmp;
          end if;
        else
          fract (fraction_width-1 downto fraction_width-1-(arg_int'high-1)) :=
            arg_int (arg_int'high-1 downto 0);
        end if;
      end if;
      expon                              := UNSIGNED (resize (exp-1, exponent_width));
      expon(exponent_width-1)            := not expon(exponent_width-1);
      result (exponent_width-1 downto 0) := float(expon);
      result (-1 downto -fraction_width) := float(fract);
    end if;
    return result;
  end function to_float;

  function to_float (
    arg                     : sfixed;
    constant exponent_width : NATURAL    := float_exponent_width;  -- length of FP output exponent
    constant fraction_width : NATURAL    := float_fraction_width;  -- length of FP output fraction
    constant round_style    : round_type := float_round_style;  -- rounding
    constant denormalize    : BOOLEAN    := float_denormalize)  -- rounding option
    return float is
    constant integer_width     : INTEGER := arg'high;
    constant in_fraction_width : INTEGER := arg'low;
    variable xresult           : sfixed (integer_width downto in_fraction_width);
    variable result            : float (exponent_width downto -fraction_width);
    variable arg_int : UNSIGNED(integer_width - in_fraction_width - 1
                                downto 0);  -- signed version of argument
    variable argx        : SIGNED (integer_width - in_fraction_width downto 0);
    variable exp, exptmp : SIGNED (exponent_width downto 0);
    variable expon       : UNSIGNED (exponent_width - 1 downto 0);
    -- Unsigned version of exp.
    constant expon_base  : SIGNED (exponent_width-1 downto 0) :=
      gen_expon_base(exponent_width);   -- exponent offset
    variable fract, fracttmp : UNSIGNED (fraction_width-1 downto 0) :=
      (others => '0');
    variable round : BOOLEAN := false;
  begin
    xresult := to_01(arg, 'X');
    argx    := SIGNED(to_slv(xresult));
    if (or_reducex (UNSIGNED(argx)) = 'X') then
      result := (others => 'X');
    elsif (argx = 0) then
      result := (others => '0');
    else
      result := (others => '0');        -- zero out the result
      if argx(argx'left) = '1' then     -- toss the sign bit
        result (exponent_width) := '1';     -- Negative number
        argx                    := -argx;   -- Make it positive.
      else
        result (exponent_width) := '0';
      end if;
      arg_int := UNSIGNED(to_x01(STD_LOGIC_VECTOR (argx(arg_int'range))));
      -- Compute Exponent
      exp     := to_signed(find_msb(arg_int, '1'), exp'length);    -- Log2
      if exp + in_fraction_width > expon_base then  -- return infinity
        result (-1 downto -fraction_width)  := (others => '0');
        result (exponent_width -1 downto 0) := (others => '1');
        return result;
      elsif (denormalize and
             (exp + in_fraction_width <= -resize(expon_base, exp'length))) then
        exp := -resize(expon_base, exp'length);
        -- shift by a constant
        arg_int := shift_left (arg_int,
                               (arg_int'high + to_integer(expon_base)
                                + in_fraction_width - 1));
        if (arg_int'high > fraction_width) then
          fract := arg_int (arg_int'high-1 downto (arg_int'high-fraction_width));
          round := check_round (
            fract_in    => arg_int(arg_int'high-fraction_width),
            sign        => result(result'high),
            remainder   => arg_int((arg_int'high-fraction_width-1)
                                   downto 0),
            round_style => round_style);
          if (round) then
            fp_round (fract_in => arg_int (arg_int'high-1 downto
                                           (arg_int'high-fraction_width)),
                      expon_in  => exp,
                      fract_out => fract,
                      expon_out => exptmp);
            exp := exptmp;
          end if;
        else
          fract (fraction_width-1 downto fraction_width-1-(arg_int'high-1)) :=
            arg_int (arg_int'high-1 downto 0);
        end if;
      else
        arg_int := shift_left (arg_int, arg_int'high-to_integer(exp));
        exp     := exp + in_fraction_width;
        if (arg_int'high > fraction_width) then
          fract := arg_int (arg_int'high-1 downto (arg_int'high-fraction_width));
          round := check_round (
            fract_in    => fract(0),
            sign        => result(result'high),
            remainder   => arg_int((arg_int'high-fraction_width-1)
                                   downto 0),
            round_style => round_style);
          if (round) then
            fp_round (fract_in  => fract,
                      expon_in  => exp,
                      fract_out => fracttmp,
                      expon_out => exptmp);
            fract := fracttmp;
            exp   := exptmp;
          end if;
        else
          fract (fraction_width-1 downto fraction_width-1-(arg_int'high-1)) :=
            arg_int (arg_int'high-1 downto 0);
        end if;
      end if;
      expon                              := UNSIGNED (resize(exp-1, exponent_width));
      expon(exponent_width-1)            := not expon(exponent_width-1);
      result (exponent_width-1 downto 0) := float(expon);
      result (-1 downto -fraction_width) := float(fract);
    end if;
    return result;
  end function to_float;

  -- size_res functions
  -- Integer to float
  function to_float (
    arg                  : INTEGER;
    size_res             : float;
    constant round_style : round_type := float_round_style)  -- rounding option
    return float is
    variable result : float (size_res'left downto size_res'right);
  begin
    if (result'length < 1) then
      return result;
    else
      result := to_float (arg            => arg,
                          exponent_width => size_res'high,
                          fraction_width => -size_res'low,
                          round_style    => round_style);
      return result;
    end if;
  end function to_float;

  -- real to float
  function to_float (
    arg                  : REAL;
    size_res             : float;
    constant round_style : round_type := float_round_style;  -- rounding option
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    variable result : float (size_res'left downto size_res'right);
  begin
    if (result'length < 1) then
      return result;
    else
      result := to_float (arg            => arg,
                          exponent_width => size_res'high,
                          fraction_width => -size_res'low,
                          round_style    => round_style,
                          denormalize    => denormalize);
      return result;
    end if;
  end function to_float;

  -- unsigned to float
  function to_float (
    arg                  : UNSIGNED;
    size_res             : float;
    constant round_style : round_type := float_round_style)  -- rounding option
    return float is
    variable result : float (size_res'left downto size_res'right);
  begin
    if (result'length < 1) then
      return result;
    else
      result := to_float (arg            => arg,
                          exponent_width => size_res'high,
                          fraction_width => -size_res'low,
                          round_style    => round_style);
      return result;
    end if;
  end function to_float;

  -- signed to float
  function to_float (
    arg                  : SIGNED;
    size_res             : float;
    constant round_style : round_type := float_round_style)  -- rounding
    return float is
    variable result : float (size_res'left downto size_res'right);
  begin
    if (result'length < 1) then
      return result;
    else
      result := to_float (arg            => arg,
                          exponent_width => size_res'high,
                          fraction_width => -size_res'low,
                          round_style    => round_style);
      return result;
    end if;
  end function to_float;

  -- std_logic_vector to float
  function to_float (
    arg      : STD_LOGIC_VECTOR;
    size_res : float)
    return float is
    variable result : float (size_res'left downto size_res'right);
  begin
    if (result'length < 1) then
      return result;
    else
      result := to_float (arg            => arg,
                          exponent_width => size_res'high,
                          fraction_width => -size_res'low);
      return result;
    end if;
  end function to_float;

  -- std_ulogic_vector to float
  function to_float (
    arg      : STD_ULOGIC_VECTOR;
    size_res : float)
    return float is
    variable result : float (size_res'left downto size_res'right);
  begin
    if (result'length < 1) then
      return result;
    else
      result := to_float (arg            => to_stdlogicvector(arg),
                          exponent_width => size_res'high,
                          fraction_width => -size_res'low);
      return result;
    end if;
  end function to_float;

  -- unsigned fixed point to float
  function to_float (
    arg                  : ufixed;      -- unsigned fixed point input
    size_res             : float;
    constant round_style : round_type := float_round_style;  -- rounding
    constant denormalize : BOOLEAN    := float_denormalize)  -- use ieee extentions
    return float is
    variable result : float (size_res'left downto size_res'right);
  begin
    if (result'length < 1) then
      return result;
    else
      result := to_float (arg            => arg,
                          exponent_width => size_res'high,
                          fraction_width => -size_res'low,
                          round_style    => round_style,
                          denormalize    => denormalize);
      return result;
    end if;
  end function to_float;

  -- signed fixed point to float
  function to_float (
    arg                  : sfixed;
    size_res             : float;
    constant round_style : round_type := float_round_style;  -- rounding
    constant denormalize : BOOLEAN    := float_denormalize)  -- rounding option
    return float is
    variable result : float (size_res'left downto size_res'right);
  begin
    if (result'length < 1) then
      return result;
    else
      result := to_float (arg            => arg,
                          exponent_width => size_res'high,
                          fraction_width => -size_res'low,
                          round_style    => round_style,
                          denormalize    => denormalize);
      return result;
    end if;
  end function to_float;

  -- fp_to_integer - Floating point to integer
  -- Note, to do an "int" function, call this routine with the
  -- round_style set to "round_zero".
  -- Synthesizable
  function to_integer (
    arg                  : float;       -- floating point input
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant round_style : round_type := float_round_style)  -- rounding option
    return INTEGER is
    variable validfp : valid_fpstate;   -- Valid FP state
    variable frac    : UNSIGNED (30 downto 0);               -- Fraction
    variable result  : INTEGER;
    variable sign    : STD_ULOGIC;      -- true if negative
  begin
    validfp := class (arg, check_error);
    classcase : case validfp is
      when isx | nan | quiet_nan | pos_zero | neg_zero | pos_denormal | neg_denormal =>
        result := 0;                    -- return 0
      when pos_inf =>
        result := INTEGER'high;
      when neg_inf =>
        result := INTEGER'low;
      when others =>
        float_to_unsigned (
          arg         => arg,
          frac        => frac,
          sign        => sign,
          denormalize => false,
          bias        => 0,
          round_style => round_style);
        -- Add the sign bit back in.
        if sign = '1' then
          -- Because the most negative signed number is 1 less than the most
          -- positive signed number, we need this code.
          if and_reducex(frac) = '1' then  -- return most negative number
            result := INTEGER'low;
          else
            result := -to_integer(frac);
          end if;
        else
          result := to_integer(frac);
        end if;
    end case classcase;
    return result;
  end function to_integer;

  -- fp_to_unsigned - floating point to unsigned number
  -- Synthesizable
  function to_unsigned (
    arg                  : float;       -- floating point input
    constant size        : NATURAL;     -- length of output
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant round_style : round_type := float_round_style)  -- rounding option
    return UNSIGNED is
    variable validfp : valid_fpstate;   -- Valid FP state
    variable frac    : UNSIGNED (size-1 downto 0);           -- Fraction
    variable sign    : STD_ULOGIC;      -- not used
  begin
    validfp := class (arg, check_error);
    classcase : case validfp is
      when isx | nan | quiet_nan =>
        frac := (others => 'X');
      when pos_zero | neg_inf | neg_zero | neg_normal | pos_denormal | neg_denormal =>
        frac := (others => '0');        -- return 0
      when pos_inf =>
        frac := (others => '1');
      when others =>
        float_to_unsigned (
          arg         => arg,
          frac        => frac,
          sign        => sign,
          denormalize => false,
          bias        => 0,
          round_style => round_style);
    end case classcase;
    return (frac);
  end function to_unsigned;

  -- fp_to_signed - floating point to signed number
  -- Synthesizable
  function to_signed (
    arg                  : float;       -- floating point input
    constant size        : NATURAL;     -- length of output
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant round_style : round_type := float_round_style)  -- rounding option
    return SIGNED is
    variable sign    : STD_ULOGIC;      -- true if negative
    variable validfp : valid_fpstate;   -- Valid FP state
    variable frac    : UNSIGNED (size-1 downto 0);           -- Fraction
    variable result  : SIGNED (size-1 downto 0);
  begin
    validfp := class (arg, check_error);
    classcase : case validfp is
      when isx | nan | quiet_nan =>
        result := (others => 'X');
      when pos_zero | neg_zero | pos_denormal | neg_denormal =>
        result := (others => '0');      -- return 0
      when pos_inf =>
        result               := (others => '1');
        result (result'high) := '0';
      when neg_inf =>
        result               := (others => '0');
        result (result'high) := '1';
      when others =>
        float_to_unsigned (
          arg         => arg,
          sign        => sign,
          frac        => frac,
          denormalize => false,
          bias        => 0,
          round_style => round_style);
        result (size-1)          := '0';
        result (size-2 downto 0) := SIGNED(frac (size-2 downto 0));
        if sign = '1' then
          -- Because the most negative signed number is 1 less than the most
          -- positive signed number, we need this code.
          if frac(frac'high) = '1' then  -- return most negative number
            result               := (others => '0');
            result (result'high) := '1';
          else
            result := -result;
          end if;
        else
          if frac(frac'high) = '1' then  -- return most positive number
            result               := (others => '1');
            result (result'high) := '0';
          end if;
        end if;
    end case classcase;
    return result;
  end function to_signed;

  -- purpose: Converts a float to ufixed
  function to_ufixed (
    arg                     : float;    -- fp input
    constant left_index     : INTEGER;  -- integer part
    constant right_index    : INTEGER;  -- fraction part
    constant round_style    : BOOLEAN := fixed_round_style;  -- rounding
    constant overflow_style : BOOLEAN := fixed_overflow_style;       -- saturate
    constant check_error    : BOOLEAN := float_check_error;  -- check for errors
    constant denormalize    : BOOLEAN := float_denormalize)
    return ufixed is
    constant fraction_width : INTEGER                    := -minx(arg'low, arg'low);  -- length of FP output fraction
    constant exponent_width : INTEGER                    := arg'high;  -- length of FP output exponent
    constant size           : INTEGER                    := left_index - right_index + 4;  -- unsigned size
    variable expon_base     : INTEGER;  -- exponent offset
    variable validfp        : valid_fpstate;                 -- Valid FP state
    variable exp            : INTEGER;  -- Exponent
    variable expon          : UNSIGNED (exponent_width-1 downto 0);  -- Vectorized exponent
    -- Base to divide fraction by
    variable frac           : UNSIGNED (size-1 downto 0) := (others => '0');  -- Fraction
    variable frac_shift     : UNSIGNED (size-1 downto 0);    -- Fraction shifted
    variable shift          : INTEGER;
    variable result_big     : ufixed (left_index downto right_index-3);
    variable result         : ufixed (left_index downto right_index);  -- result
  begin  -- function to_ufixed
    validfp := class (arg, check_error);
    classcase : case validfp is
      when isx | nan | quiet_nan =>
        frac := (others => 'X');
      when pos_zero | neg_inf | neg_zero | neg_normal | neg_denormal =>
        frac := (others => '0');        -- return 0
      when pos_inf =>
        frac := (others => '1');        -- always saturate
      when others =>
        expon_base := 2**(exponent_width-1) -1;  -- exponent offset
        -- Figure out the fraction
        if (validfp = pos_denormal) and denormalize then
          exp              := -expon_base +1;
          frac (frac'high) := '0';      -- Add the "1.0".
        else
          -- exponent /= '0', normal floating point
          expon                   := UNSIGNED(arg (exponent_width-1 downto 0));
          expon(exponent_width-1) := not expon(exponent_width-1);
          exp                     := to_integer (SIGNED(expon)) +1;
          frac (frac'high)        := '1';   -- Add the "1.0".
        end if;
        shift := (frac'high - 3 + right_index) - exp;
        if fraction_width > frac'high then  -- Can only use size-2 bits
          frac (frac'high-1 downto 0) := UNSIGNED (to_slv (arg(-1 downto
                                                               -frac'high)));
        else                            -- can use all bits
          frac (frac'high-1 downto frac'high-fraction_width) :=
            UNSIGNED (to_slv (arg(-1 downto -fraction_width)));
        end if;
        frac_shift := frac srl shift;
        if shift < 0 then               -- Overflow
          frac := (others => '1');
        else
          frac := frac_shift;
        end if;
    end case classcase;
    result_big := to_ufixed (arg         => STD_LOGIC_VECTOR(frac),
                             left_index  => left_index,
                             right_index => (right_index-3));
    result := resize (arg            => result_big,
                      left_index     => left_index,
                      right_index    => right_index,
                      round_style    => round_style,
                      overflow_style => overflow_style);
    return result;
  end function to_ufixed;

  -- purpose: Converts a float to sfixed
  function to_sfixed (
    arg                     : float;    -- fp input
    constant left_index     : INTEGER;  -- integer part
    constant right_index    : INTEGER;  -- fraction part
    constant round_style    : BOOLEAN := fixed_round_style;  -- rounding
    constant overflow_style : BOOLEAN := fixed_overflow_style;       -- saturate
    constant check_error    : BOOLEAN := float_check_error;  -- check for errors
    constant denormalize    : BOOLEAN := float_denormalize)
    return sfixed is
    constant fraction_width : INTEGER                                := -minx(arg'low, arg'low);  -- length of FP output fraction
    constant exponent_width : INTEGER                                := arg'high;  -- length of FP output exponent
    constant size           : INTEGER                                := left_index - right_index + 4;  -- unsigned size
    variable expon_base     : INTEGER;  -- exponent offset
    variable validfp        : valid_fpstate;     -- Valid FP state
    variable exp            : INTEGER;  -- Exponent
    variable sign           : BOOLEAN;  -- true if negative
    variable expon          : UNSIGNED (exponent_width-1 downto 0);  -- Vectorized exponent
    -- Base to divide fraction by
    variable frac           : UNSIGNED (size-2 downto 0)             := (others => '0');  -- Fraction
    variable frac_shift     : UNSIGNED (size-2 downto 0);    -- Fraction shifted
    variable shift          : INTEGER;
    variable rsigned        : SIGNED (size-1 downto 0);  -- signed version of result
    variable result_big     : sfixed (left_index downto right_index-3);
    variable result         : sfixed (left_index downto right_index) := (others => '0');  -- result
  begin  -- function to_ufixed
    validfp := class (arg, check_error);
    classcase : case validfp is
      when isx | nan | quiet_nan =>
        result := (others => 'X');
      when pos_zero | neg_zero =>
        result := (others => '0');      -- return 0
      when neg_inf =>
        result (left_index) := '1';     -- return smallest negative number
      when pos_inf =>
        result              := (others => '1');  -- return largest number
        result (left_index) := '0';
      when others =>
        expon_base := 2**(exponent_width-1) -1;  -- exponent offset
        if arg(exponent_width) = '0' then
          sign := false;
        else
          sign := true;
        end if;
        -- Figure out the fraction
        if (validfp = pos_denormal or validfp = neg_denormal)
          and denormalize then
          exp              := -expon_base +1;
          frac (frac'high) := '0';      -- Add the "1.0".
        else
          -- exponent /= '0', normal floating point
          expon                   := UNSIGNED(arg (exponent_width-1 downto 0));
          expon(exponent_width-1) := not expon(exponent_width-1);
          exp                     := to_integer (SIGNED(expon)) +1;
          frac (frac'high)        := '1';        -- Add the "1.0".
        end if;
        shift := (frac'high - 3 + right_index) - exp;
        if fraction_width > frac'high then       -- Can only use size-2 bits
          frac (frac'high-1 downto 0) := UNSIGNED (to_slv (arg(-1 downto
                                                               -frac'high)));
        else                            -- can use all bits
          frac (frac'high-1 downto frac'high-fraction_width) :=
            UNSIGNED (to_slv (arg(-1 downto -fraction_width)));
        end if;
        frac_shift := frac srl shift;
        if shift < 0 then               -- Overflow
          frac := (others => '1');
        else
          frac := frac_shift;
        end if;
        if not sign then
          rsigned := SIGNED("0" & frac);
        else
          rsigned := -(SIGNED("0" & frac));
        end if;
        result_big := to_sfixed (arg         => STD_LOGIC_VECTOR(rsigned),
                                 left_index  => left_index,
                                 right_index => (right_index-3));
        result := resize (arg            => result_big,
                          left_index     => left_index,
                          right_index    => right_index,
                          round_style    => round_style,
                          overflow_style => overflow_style);
    end case classcase;
    return result;
  end function to_sfixed;

  -- size_res versions
  -- float to unsigned
  function to_unsigned (
    arg                  : float;       -- floating point input
    size_res             : UNSIGNED;
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant round_style : round_type := float_round_style)  -- rounding option
    return UNSIGNED is
    variable result : UNSIGNED (size_res'range);
  begin
    if (SIZE_RES'length = 0) then
      return result;
    else
      result := to_unsigned (arg         => arg,
                             size        => size_res'length,
                             check_error => check_error,
                             round_style => round_style);
      return result;
    end if;
  end function to_unsigned;

  -- float to signed
  function to_signed (
    arg                  : float;       -- floating point input
    size_res             : SIGNED;
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant round_style : round_type := float_round_style)  -- rounding option
    return SIGNED is
    variable result : SIGNED (size_res'range);
  begin
    if (SIZE_RES'length = 0) then
      return result;
    else
      result := to_signed (arg         => arg,
                           size        => size_res'length,
                           check_error => check_error,
                           round_style => round_style);
      return result;
    end if;
  end function to_signed;

  -- purpose: Converts a float to unsigned fixed point
  function to_ufixed (
    arg                     : float;    -- fp input
    size_res                : ufixed;
    constant round_style    : BOOLEAN := fixed_round_style;  -- rounding
    constant overflow_style : BOOLEAN := fixed_overflow_style;  -- saturate
    constant check_error    : BOOLEAN := float_check_error;  -- check for errors
    constant denormalize    : BOOLEAN := float_denormalize)
    return ufixed is
    variable result : ufixed (size_res'left downto size_res'right);
  begin
    if (result'length < 1) then
      return result;
    else
      result := to_ufixed (arg            => arg,
                           left_index     => size_res'high,
                           right_index    => size_res'low,
                           round_style    => round_style,
                           overflow_style => overflow_style,
                           check_error    => check_error,
                           denormalize    => denormalize);
      return result;
    end if;
  end function to_ufixed;

  -- float to signed fixed point
  function to_sfixed (
    arg                     : float;    -- fp input
    size_res                : sfixed;
    constant round_style    : BOOLEAN := fixed_round_style;  -- rounding
    constant overflow_style : BOOLEAN := fixed_overflow_style;  -- saturate
    constant check_error    : BOOLEAN := float_check_error;  -- check for errors
    constant denormalize    : BOOLEAN := float_denormalize)
    return sfixed is
    variable result : sfixed (size_res'left downto size_res'right);
  begin
    if (result'length < 1) then
      return result;
    else
      result := to_sfixed (arg            => arg,
                           left_index     => size_res'high,
                           right_index    => size_res'low,
                           round_style    => round_style,
                           overflow_style => overflow_style,
                           check_error    => check_error,
                           denormalize    => denormalize);
      return result;
    end if;
  end function to_sfixed;

  -- Floating point to Real number conversion
  -- Not Synthesizable
  function to_real (
    arg                  : float;       -- floating point input
    constant round_style : round_type := float_round_style;  -- rounding option
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return REAL is
    constant fraction_width : INTEGER := -minx(arg'low, arg'low);  -- length of FP output fraction
    constant exponent_width : INTEGER := arg'high;  -- length of FP output exponent
    variable sign           : REAL;     -- Sign, + or - 1
    variable exp            : INTEGER;  -- Exponent
    variable expon_base     : INTEGER;  -- exponent offset
    variable frac           : REAL    := 0.0;       -- Fraction
    variable validfp        : valid_fpstate;        -- Valid FP state
    variable expon          : UNSIGNED (exponent_width - 1 downto 0)
 := (others => '1');                    -- Vectorized exponent
  begin
    validfp := class (arg, check_error);
    classcase : case validfp is
      when isx | pos_zero | neg_zero | nan | quiet_nan =>
        return 0.0;
      when neg_inf =>
        return REAL'low;                -- Negative infinity.
      when pos_inf =>
        return REAL'high;               -- Positive infinity
      when others =>
        expon_base  := 2**(exponent_width-1) -1;
        if to_X01(arg(exponent_width)) = '0' then
          sign := 1.0;
        else
          sign := -1.0;
        end if;
        -- Figure out the fraction
        for i in 0 to fraction_width-1 loop
          if to_X01(arg (-1 - i)) = '1' then
            frac := frac + (2.0 **(-1 - i));
          end if;
        end loop;  -- i
        if validfp = pos_normal or validfp = neg_normal or not denormalize then
          -- exponent /= '0', normal floating point
          expon                   := UNSIGNED(arg (exponent_width-1 downto 0));
          expon(exponent_width-1) := not expon(exponent_width-1);
          exp                     := to_integer (SIGNED(expon)) +1;
          sign                    := sign * (2.0 ** exp) * (1.0 + frac);
        else  -- exponent = '0', IEEE extended floating point
          exp  := 1 - expon_base;
          sign := sign * (2.0 ** exp) * frac;
        end if;
        return sign;
    end case classcase;
  end function to_real;

  -- purpose: Removes meta-logical values from FP string
  function to_01 (
    arg  : float;                       -- floating point input
    XMAP : STD_LOGIC := '0')
    return float is
    variable BAD_ELEMENT : BOOLEAN := false;
    variable RESULT      : float (arg'range);
  begin  -- function to_01
    if (arg'length < 1) then
      assert NO_WARNING
        report "FLOAT_GENERIC_PKG.TO_01: null detected, returning NAFP"
        severity warning;
      return NAFP;
    end if;
    for I in RESULT'range loop
      case arg(I) is
        when '0' | 'L' => RESULT(I)   := '0';
        when '1' | 'H' => RESULT(I)   := '1';
        when others    => BAD_ELEMENT := true;
      end case;
    end loop;
    if BAD_ELEMENT then
      RESULT := (others => XMAP);
    end if;
    return RESULT;
  end function to_01;

  function Is_X
    (arg : float)
    return BOOLEAN is
  begin
    return Is_X (to_slv(arg));
  end function Is_X;

  function to_X01 (arg : float) return float is
  begin
    if (arg'length < 1) then
      assert NO_WARNING
        report "FLOAT_GENERIC_PKG.TO_X01: null detected, returning NAFP"
        severity warning;
      return NAFP;
    else
      return to_float (to_X01(to_slv(arg)), arg'high, -arg'low);
    end if;
  end function to_X01;

  function to_X01Z (arg : float) return float is
  begin
    if (arg'length < 1) then
      assert NO_WARNING
        report "FLOAT_GENERIC_PKG.TO_X01Z: null detected, returning NAFP"
        severity warning;
      return NAFP;
    else
      return to_float (to_X01Z(to_slv(arg)), arg'high, -arg'low);
    end if;
  end function to_X01Z;

  function to_UX01 (arg : float) return float is
  begin
    if (arg'length < 1) then
      assert NO_WARNING
        report "FLOAT_GENERIC_PKG.TO_UX01: null detected, returning NAFP"
        severity warning;
      return NAFP;
    else
      return to_float (to_UX01(to_slv(arg)), arg'high, -arg'low);
    end if;
  end function to_UX01;

  -- These allows the base math functions to use the default values
  -- of their parameters.  Thus they do full IEEE floating point.
  function "+" (l, r : float) return float is
  begin
    return add (l, r);
  end function "+";
  function "-" (l, r : float) return float is
  begin
    return subtract (l, r);
  end function "-";
  function "*" (l, r : float) return float is
  begin
    return multiply (l, r);
  end function "*";
  function "/" (l, r : float) return float is
  begin
    return divide (l, r);
  end function "/";
  function "rem" (l, r : float) return float is
  begin
    return remainder (l, r);
  end function "rem";
  function "mod" (l, r : float) return float is
  begin
    return modulo (l, r);
  end function "mod";
  -- overloaded versions
  function "+" (l : float; r : REAL) return float is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return add (l, r_float);
  end function "+";

  function "+" (l : REAL; r : float) return float is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return add (l_float, r);
  end function "+";

  function "+" (l : float; r : INTEGER) return float is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return add (l, r_float);
  end function "+";

  function "+" (l : INTEGER; r : float) return float is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return add (l_float, r);
  end function "+";

  function "-" (l : float; r : REAL) return float is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return subtract (l, r_float);
  end function "-";

  function "-" (l : REAL; r : float) return float is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return subtract (l_float, r);
  end function "-";

  function "-" (l : float; r : INTEGER) return float is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return subtract (l, r_float);
  end function "-";

  function "-" (l : INTEGER; r : float) return float is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return subtract (l_float, r);
  end function "-";

  function "*" (l : float; r : REAL) return float is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return multiply (l, r_float);
  end function "*";

  function "*" (l : REAL; r : float) return float is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return multiply (l_float, r);
  end function "*";

  function "*" (l : float; r : INTEGER) return float is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return multiply (l, r_float);
  end function "*";

  function "*" (l : INTEGER; r : float) return float is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return multiply (l_float, r);
  end function "*";

  function "/" (l : float; r : REAL) return float is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return divide (l, r_float);
  end function "/";

  function "/" (l : REAL; r : float) return float is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return divide (l_float, r);
  end function "/";

  function "/" (l : float; r : INTEGER) return float is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return divide (l, r_float);
  end function "/";

  function "/" (l : INTEGER; r : float) return float is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return divide (l_float, r);
  end function "/";

  function "rem" (l : float; r : REAL) return float is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return remainder (l, r_float);
  end function "rem";

  function "rem" (l : REAL; r : float) return float is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return remainder (l_float, r);
  end function "rem";

  function "rem" (l : float; r : INTEGER) return float is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return remainder (l, r_float);
  end function "rem";

  function "rem" (l : INTEGER; r : float) return float is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return remainder (l_float, r);
  end function "rem";

  function "mod" (l : float; r : REAL) return float is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return modulo (l, r_float);
  end function "mod";

  function "mod" (l : REAL; r : float) return float is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return modulo (l_float, r);
  end function "mod";

  function "mod" (l : float; r : INTEGER) return float is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return modulo (l, r_float);
  end function "mod";

  function "mod" (l : INTEGER; r : float) return float is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return modulo (l_float, r);
  end function "mod";

  function "=" (l : float; r : REAL) return BOOLEAN is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return eq (l, r_float);
  end function "=";

  function "/=" (l : float; r : REAL) return BOOLEAN is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return ne (l, r_float);
  end function "/=";

  function ">=" (l : float; r : REAL) return BOOLEAN is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return ge (l, r_float);
  end function ">=";

  function "<=" (l : float; r : REAL) return BOOLEAN is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return le (l, r_float);
  end function "<=";

  function ">" (l : float; r : REAL) return BOOLEAN is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return gt (l, r_float);
  end function ">";

  function "<" (l : float; r : REAL) return BOOLEAN is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return lt (l, r_float);
  end function "<";

  function "=" (l : REAL; r : float) return BOOLEAN is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return eq (l_float, r);
  end function "=";

  function "/=" (l : REAL; r : float) return BOOLEAN is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return ne (l_float, r);
  end function "/=";

  function ">=" (l : REAL; r : float) return BOOLEAN is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return ge (l_float, r);
  end function ">=";

  function "<=" (l : REAL; r : float) return BOOLEAN is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return le (l_float, r);
  end function "<=";

  function ">" (l : REAL; r : float) return BOOLEAN is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return gt (l_float, r);
  end function ">";

  function "<" (l : REAL; r : float) return BOOLEAN is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return lt (l_float, r);
  end function "<";

  function "=" (l : float; r : INTEGER) return BOOLEAN is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return eq (l, r_float);
  end function "=";

  function "/=" (l : float; r : INTEGER) return BOOLEAN is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return ne (l, r_float);
  end function "/=";

  function ">=" (l : float; r : INTEGER) return BOOLEAN is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return ge (l, r_float);
  end function ">=";

  function "<=" (l : float; r : INTEGER) return BOOLEAN is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return le (l, r_float);
  end function "<=";

  function ">" (l : float; r : INTEGER) return BOOLEAN is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return gt (l, r_float);
  end function ">";

  function "<" (l : float; r : INTEGER) return BOOLEAN is
    variable r_float : float (l'range);
  begin
    r_float := to_float (r, l);         -- use size_res function
    return lt (l, r_float);
  end function "<";

  function "=" (l : INTEGER; r : float) return BOOLEAN is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return eq (l_float, r);
  end function "=";

  function "/=" (l : INTEGER; r : float) return BOOLEAN is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return ne (l_float, r);
  end function "/=";

  function ">=" (l : INTEGER; r : float) return BOOLEAN is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return ge (l_float, r);
  end function ">=";

  function "<=" (l : INTEGER; r : float) return BOOLEAN is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return le (l_float, r);
  end function "<=";

  function ">" (l : INTEGER; r : float) return BOOLEAN is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return gt (l_float, r);
  end function ">";

  function "<" (l : INTEGER; r : float) return BOOLEAN is
    variable l_float : float (r'range);
  begin
    l_float := to_float(l, r);
    return lt (l_float, r);
  end function "<";

  ----------------------------------------------------------------------------
  -- logical functions
  ----------------------------------------------------------------------------
  function "not" (L : float) return float is
    variable RESULT : STD_LOGIC_VECTOR(L'length-1 downto 0);  -- force downto
    variable resfp  : float (L'range);                        -- back to float
  begin
    RESULT := not to_slv(L);
    resfp  := float (RESULT);
    return resfp;
  end function "not";

  function "and" (L, R : float) return float is
    variable RESULT : STD_LOGIC_VECTOR(L'length-1 downto 0);  -- force downto
    variable resfp  : float (L'range);                        -- back to float
  begin
    RESULT := to_slv(L) and to_slv(R);
    resfp  := float (RESULT);
    return resfp;
  end function "and";

  function "or" (L, R : float) return float is
    variable RESULT : STD_LOGIC_VECTOR(L'length-1 downto 0);  -- force downto
    variable resfp  : float (L'range);                        -- back to float
  begin
    RESULT := to_slv(L) or to_slv(R);
    resfp  := float (RESULT);
    return resfp;
  end function "or";

  function "nand" (L, R : float) return float is
    variable RESULT : STD_LOGIC_VECTOR(L'length-1 downto 0);  -- force downto
    variable resfp  : float (L'range);                        -- back to float
  begin
    RESULT := to_slv(L) nand to_slv(R);
    resfp  := float (RESULT);
    return resfp;
  end function "nand";

  function "nor" (L, R : float) return float is
    variable RESULT : STD_LOGIC_VECTOR(L'length-1 downto 0);  -- force downto
    variable resfp  : float (L'range);                        -- back to float
  begin
    RESULT := to_slv(L) nor to_slv(R);
    resfp  := float (RESULT);
    return resfp;
  end function "nor";

  function "xor" (L, R : float) return float is
    variable RESULT : STD_LOGIC_VECTOR(L'length-1 downto 0);  -- force downto
    variable resfp  : float (L'range);                        -- back to float
  begin
    RESULT := to_slv(L) xor to_slv(R);
    resfp  := float (RESULT);
    return resfp;
  end function "xor";

  function "xnor" (L, R : float) return float is
    variable RESULT : STD_LOGIC_VECTOR(L'length-1 downto 0);  -- force downto
    variable resfp  : float (L'range);                        -- back to float
  begin
    RESULT := to_slv(L) xnor to_slv(R);
    resfp  := float (RESULT);
    return resfp;
  end function "xnor";

  -- Vector and std_ulogic functions, same as functions in numeric_std
  function "and" (L : STD_ULOGIC; R : float) return float is
    variable result : float (R'range);
  begin
    for i in result'range loop
      result(i) := L and R(i);
    end loop;
    return result;
  end function "and";

  function "and" (L : float; R : STD_ULOGIC) return float is
    variable result : float (L'range);
  begin
    for i in result'range loop
      result(i) := L(i) and R;
    end loop;
    return result;
  end function "and";

  function "or" (L : STD_ULOGIC; R : float) return float is
    variable result : float (R'range);
  begin
    for i in result'range loop
      result(i) := L or R(i);
    end loop;
    return result;
  end function "or";

  function "or" (L : float; R : STD_ULOGIC) return float is
    variable result : float (L'range);
  begin
    for i in result'range loop
      result(i) := L(i) or R;
    end loop;
    return result;
  end function "or";

  function "nand" (L : STD_ULOGIC; R : float) return float is
    variable result : float (R'range);
  begin
    for i in result'range loop
      result(i) := L nand R(i);
    end loop;
    return result;
  end function "nand";

  function "nand" (L : float; R : STD_ULOGIC) return float is
    variable result : float (L'range);
  begin
    for i in result'range loop
      result(i) := L(i) nand R;
    end loop;
    return result;
  end function "nand";

  function "nor" (L : STD_ULOGIC; R : float) return float is
    variable result : float (R'range);
  begin
    for i in result'range loop
      result(i) := L nor R(i);
    end loop;
    return result;
  end function "nor";

  function "nor" (L : float; R : STD_ULOGIC) return float is
    variable result : float (L'range);
  begin
    for i in result'range loop
      result(i) := L(i) nor R;
    end loop;
    return result;
  end function "nor";

  function "xor" (L : STD_ULOGIC; R : float) return float is
    variable result : float (R'range);
  begin
    for i in result'range loop
      result(i) := L xor R(i);
    end loop;
    return result;
  end function "xor";

  function "xor" (L : float; R : STD_ULOGIC) return float is
    variable result : float (L'range);
  begin
    for i in result'range loop
      result(i) := L(i) xor R;
    end loop;
    return result;
  end function "xor";

  function "xnor" (L : STD_ULOGIC; R : float) return float is
    variable result : float (R'range);
  begin
    for i in result'range loop
      result(i) := L xnor R(i);
    end loop;
    return result;
  end function "xnor";

  function "xnor" (L : float; R : STD_ULOGIC) return float is
    variable result : float (L'range);
  begin
    for i in result'range loop
      result(i) := L(i) xnor R;
    end loop;
    return result;
  end function "xnor";

  -- Reduction operators, same as numeric_std functions
  -- %%% remove 6 functions (old syntax)
  function and_reduce(arg : float) return STD_ULOGIC is
  begin
    return and_reducex (to_slv(arg));
  end function and_reduce;

  function nand_reduce(arg : float) return STD_ULOGIC is
  begin
    return not and_reducex (to_slv(arg));
  end function nand_reduce;

  function or_reduce(arg : float) return STD_ULOGIC is
  begin
    return or_reducex (to_slv(arg));
  end function or_reduce;

  function nor_reduce(arg : float) return STD_ULOGIC is
  begin
    return not or_reducex (to_slv(arg));
  end function nor_reduce;

  function xor_reduce(arg : float) return STD_ULOGIC is
  begin
    return xor_reducex (to_slv(arg));
  end function xor_reduce;

  function xnor_reduce(arg : float) return STD_ULOGIC is
  begin
    return not xor_reducex (to_slv(arg));
  end function xnor_reduce;

  -- %%% Uncomment the following 6 functions (new syntax)
  -- function "and" ( arg  : float ) RETURN std_ulogic is
  -- begin
  --   return and to_slv(arg);
  -- end function "and";
  -- function "nand" ( arg  : float ) RETURN std_ulogic is
  -- begin
  --   return nand to_slv(arg);
  -- end function "nand";;
  -- function "or" ( arg  : float ) RETURN std_ulogic is
  -- begin
  --   return or to_slv(arg);
  -- end function "or";
  -- function "nor" ( arg  : float ) RETURN std_ulogic is
  -- begin
  --   return nor to_slv(arg);
  -- end function "nor";
  -- function "xor" ( arg  : float ) RETURN std_ulogic is
  -- begin
  --   return xor to_slv(arg);
  -- end function "xor";
  -- function "xnor" ( arg  : float ) RETURN std_ulogic is
  -- begin
  --   return xnor to_slv(arg);
  -- end function "xnor"; 
  -----------------------------------------------------------------------------
  -- Recommended Functions from the IEEE 754 Appendix
  -----------------------------------------------------------------------------
  -- returns x with the sign of y.
  function Copysign (
    x, y : float)                       -- floating point input
    return float is
  begin
    return y(y'high) & x (x'high-1 downto x'low);
  end function Copysign;

  -- Returns y * 2**n for integral values of N without computing 2**n
  function Scalb (
    y                    : float;       -- floating point input
    N                    : INTEGER;     -- exponent to add    
    constant round_style : round_type := float_round_style;  -- rounding option
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    constant fraction_width : NATURAL := -minx(y'low, y'low);  -- length of FP output fraction
    constant exponent_width : NATURAL := y'high;  -- length of FP output exponent
    variable arg, result    : float (exponent_width downto -fraction_width);  -- internal argument
    variable expon          : SIGNED (exponent_width-1 downto 0);  -- Vectorized exp
    variable exp            : SIGNED (exponent_width downto 0);
    variable ufract         : UNSIGNED (fraction_width downto 0);
    constant expon_base     : SIGNED (exponent_width-1 downto 0)
 := gen_expon_base(exponent_width);     -- exponent offset
    variable fptype : valid_fpstate;
  begin
    -- This can be done by simply adding N to the exponent.
    arg    := to_01 (y, 'X');
    fptype := class(arg, check_error);
    classcase : case fptype is
      when isx =>
        result := (others => 'X');
      when nan | quiet_nan =>
        -- Return quiet NAN, IEEE754-1985-7.1,1
        result := qnanfp (fraction_width => fraction_width,
                          exponent_width => exponent_width);
      when others =>
        break_number (
          arg         => arg,
          fptyp       => fptype,
          denormalize => denormalize,
          fract       => ufract,
          expon       => expon);
        exp := resize (expon, exp'length) + N;
        result := normalize (
          fract          => ufract,
          expon          => exp,
          sign           => to_x01 (arg (arg'high)),
          fraction_width => fraction_width,
          exponent_width => exponent_width,
          round_style    => round_style,
          denormalize    => denormalize,
          nguard         => 0);
    end case classcase;
    return result;
  end function Scalb;

  -- Returns y * 2**n for integral values of N without computing 2**n
  function Scalb (
    y                    : float;       -- floating point input
    N                    : SIGNED;      -- exponent to add    
    constant round_style : round_type := float_round_style;  -- rounding option
    constant check_error : BOOLEAN    := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN    := float_denormalize)  -- Use IEEE extended FP
    return float is
    variable n_int : INTEGER;
  begin
    n_int := to_integer(N);
    return Scalb (y           => y,
                  N           => n_int,
                  round_style => round_style,
                  check_error => check_error,
                  denormalize => denormalize);
  end function Scalb;

  -- returns the unbiased exponent of x
  function Logb (
    x : float)                          -- floating point input
    return INTEGER is
    constant fraction_width : NATURAL := -minx (x'low, x'low);  -- length of FP output fraction
    constant exponent_width : NATURAL := x'high;  -- length of FP output exponent
    variable result         : INTEGER;  -- result
    variable arg            : float (exponent_width downto -fraction_width);  -- internal argument
    variable expon          : SIGNED (exponent_width - 1 downto 0);
    variable fract          : UNSIGNED (fraction_width downto 0);
    constant expon_base     : INTEGER := 2**(exponent_width-1) -1;  -- exponent
                                                                    -- offset +1
    variable fptype         : valid_fpstate;
  begin
    -- Just return the exponent.
    arg    := to_01 (x, 'X');
    fptype := class(arg);
    classcase : case fptype is
      when isx | nan | quiet_nan =>
        -- Return quiet NAN, IEEE754-1985-7.1,1
        result := 0;
      when pos_denormal | neg_denormal =>
        fract (fraction_width)            := '0';
        fract (fraction_width-1 downto 0) :=
          UNSIGNED (to_slv(arg(-1 downto -fraction_width)));
        result := find_msb (fract, '1')           -- Find the first "1"
                  - fraction_width;     -- subtract the length we want
        result := -expon_base + 1 + result;
      when others =>
        expon                   := SIGNED(arg (exponent_width - 1 downto 0));
        expon(exponent_width-1) := not expon(exponent_width-1);
        expon                   := expon + 1;
        result                  := to_integer (expon);
    end case classcase;
    return result;
  end function Logb;

  -- returns the unbiased exponent of x
  function Logb (
    x : float)                          -- floating point input
    return SIGNED is
    constant exponent_width : NATURAL := x'high;  -- length of FP output exponent
    variable result         : SIGNED (exponent_width - 1 downto 0);  -- result
  begin
    -- Just return the exponent.
    result := to_signed (Logb (x), exponent_width);
    return result;
  end function Logb;

  -- returns the next representable neighbor of x in the direction toward y
  function Nextafter (
    x, y                 : float;       -- floating point input
    constant check_error : BOOLEAN := float_check_error;  -- check for errors
    constant denormalize : BOOLEAN := float_denormalize)
    return float is
    constant fraction_width : NATURAL := -minx(x'low, x'low);  -- length of FP output fraction
    constant exponent_width : NATURAL := x'high;  -- length of FP output exponent
    function "=" (
      l, r : float)                     -- inputs
      return BOOLEAN is
    begin  -- function "="
      return eq (l           => l,
                 r           => r,
                 check_error => false);
    end function "=";
    function ">" (
      l, r : float)                     -- inputs
      return BOOLEAN is
    begin  -- function ">"
      return gt (l           => l,
                 r           => r,
                 check_error => false);
    end function ">";
    variable fract              : UNSIGNED (fraction_width-1 downto 0);
    variable expon              : UNSIGNED (exponent_width-1 downto 0);
    variable sign               : STD_ULOGIC;
    variable result             : float (exponent_width downto -fraction_width);
    variable validfpx, validfpy : valid_fpstate;  -- Valid FP state
  begin  -- fp_Nextafter
    -- If Y > X, add one to the fraction, otherwise subtract.
    validfpx := class (x, check_error);
    validfpy := class (y, check_error);
    if validfpx = isx or validfpy = isx then
      result := (others => 'X');
      return result;
    elsif (validfpx = nan or validfpy = nan) then
      return nanfp (fraction_width => fraction_width,
                    exponent_width => exponent_width);
    elsif (validfpx = quiet_nan or validfpy = quiet_nan) then
      return qnanfp (fraction_width => fraction_width,
                     exponent_width => exponent_width);
    elsif x = y then                    -- Return X
      return x;
    else
      fract := UNSIGNED (to_slv (x (-1 downto -fraction_width)));  -- Fraction
      expon := UNSIGNED (x (exponent_width - 1 downto 0));     -- exponent
      sign  := x(exponent_width);       -- sign bit
      if (y > x) then
        -- Increase the number given
        if validfpx = neg_inf then
          -- return most negative number
          expon     := (others => '1');
          expon (0) := '0';
          fract     := (others => '1');
        elsif validfpx = pos_zero or validfpx = neg_zero then
          -- return smallest denormal number
          sign     := '0';
          expon    := (others => '0');
          fract    := (others => '0');
          fract(0) := '1';
        elsif validfpx = pos_normal then
          if and_reducex (fract) = '1' then       -- fraction is all "1".
            if and_reducex (expon (exponent_width-1 downto 1)) = '1'
              and expon (0) = '0' then
                                        -- Exponent is one away from infinity.
              assert NO_WARNING
                report "FLOAT_GENERIC_PKG.FP_NEXTAFTER: NextAfter overflow"
                severity warning;
              return pos_inffp (fraction_width => fraction_width,
                                exponent_width => exponent_width);
            else
              expon := expon + 1;
              fract := (others => '0');
            end if;
          else
            fract := fract + 1;
          end if;
        elsif validfpx = pos_denormal then
          if and_reducex (fract) = '1' then       -- fraction is all "1".
            -- return smallest possible normal number
            expon    := (others => '0');
            expon(0) := '1';
            fract    := (others => '0');
          else
            fract := fract + 1;
          end if;
        elsif validfpx = neg_normal then
          if or_reducex (fract) = '0' then        -- fraction is all "0".
            if or_reducex (expon (exponent_width-1 downto 1)) = '0' and
              expon (0) = '1' then      -- Smallest exponent
              -- return the largest negative denormal number
              expon := (others => '0');
              fract := (others => '1');
            else
              expon := expon - 1;
              fract := (others => '1');
            end if;
          else
            fract := fract - 1;
          end if;
        elsif validfpx = neg_denormal then
          if or_reducex (fract(fract'high downto 1)) = '0'
            and fract (0) = '1' then    -- Smallest possible fraction
            return zerofp (fraction_width => fraction_width,
                           exponent_width => exponent_width);
          else
            fract := fract - 1;
          end if;
        end if;
      else
        -- Decrease the number
        if validfpx = pos_inf then
          -- return most positive number
          expon     := (others => '1');
          expon (0) := '0';
          fract     := (others => '1');
        elsif validfpx = pos_zero
          or class (x) = neg_zero then
          -- return smallest negative denormal number
          sign     := '1';
          expon    := (others => '0');
          fract    := (others => '0');
          fract(0) := '1';
        elsif validfpx = neg_normal then
          if and_reducex (fract) = '1' then       -- fraction is all "1".
            if and_reducex (expon (exponent_width-1 downto 1)) = '1'
              and expon (0) = '0' then
                                        -- Exponent is one away from infinity.
              assert NO_WARNING
                report "FLOAT_GENERIC_PKG.FP_NEXTAFTER: NextAfter overflow"
                severity warning;
              return neg_inffp (fraction_width => fraction_width,
                                exponent_width => exponent_width);
            else
              expon := expon + 1;       -- Fraction overflow
              fract := (others => '0');
            end if;
          else
            fract := fract + 1;
          end if;
        elsif validfpx = neg_denormal then
          if and_reducex (fract) = '1' then       -- fraction is all "1".
            -- return smallest possible normal number
            expon    := (others => '0');
            expon(0) := '1';
            fract    := (others => '0');
          else
            fract := fract + 1;
          end if;
        elsif validfpx = pos_normal then
          if or_reducex (fract) = '0' then        -- fraction is all "0".
            if or_reducex (expon (exponent_width-1 downto 1)) = '0' and
              expon (0) = '1' then      -- Smallest exponent
              -- return the largest positive denormal number
              expon := (others => '0');
              fract := (others => '1');
            else
              expon := expon - 1;
              fract := (others => '1');
            end if;
          else
            fract := fract - 1;
          end if;
        elsif validfpx = pos_denormal then
          if or_reducex (fract(fract'high downto 1)) = '0'
            and fract (0) = '1' then    -- Smallest possible fraction
            return zerofp (fraction_width => fraction_width,
                           exponent_width => exponent_width);
          else
            fract := fract - 1;
          end if;
        end if;
      end if;
      result (-1 downto -fraction_width)  := float(fract);
      result (exponent_width -1 downto 0) := float(expon);
      result (exponent_width)             := sign;
      return result;
    end if;
  end function Nextafter;

  -- Returns True if X is unordered with Y.
  function Unordered (
    x, y : float)                       -- floating point input
    return BOOLEAN is
    variable lfptype, rfptype : valid_fpstate;
  begin
    lfptype := class (x);
    rfptype := class (y);
    if (lfptype = nan or lfptype = quiet_nan or
        rfptype = nan or rfptype = quiet_nan or
        lfptype = isx or rfptype = isx) then
      return true;
    else
      return false;
    end if;
  end function Unordered;

  function Finite (
    x : float)
    return BOOLEAN is
    variable fp_state : valid_fpstate;  -- fp state
  begin
    fp_state := Class (x);
    if (fp_state = pos_inf) or (fp_state = neg_inf) then
      return true;
    else
      return false;
    end if;
  end function Finite;

  function Isnan (
    x : float)
    return BOOLEAN is
    variable fp_state : valid_fpstate;  -- fp state
  begin
    fp_state := Class (x);
    if (fp_state = nan) or (fp_state = quiet_nan) then
      return true;
    else
      return false;
    end if;
  end function Isnan;

  -- Function to return constants.
  function zerofp (
    constant exponent_width : NATURAL := float_exponent_width;  -- exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- fraction
    return float is
    constant result : float (exponent_width downto -fraction_width) :=
      (others => '0');                  -- zero
  begin
    return result;
  end function zerofp;
  function nanfp (
    constant exponent_width : NATURAL := float_exponent_width;  -- exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- fraction
    return float is
    variable result : float (exponent_width downto -fraction_width) :=
      (others => '0');                  -- zero
  begin
    result (exponent_width-1 downto 0) := (others => '1');
    -- Exponent all "1"
    result (-1)                        := '1';  -- MSB of Fraction "1"
    -- Note: From W. Khan "IEEE Standard 754 for Binary Floating Point"
    -- The difference between a signaling NAN and a quiet NAN is that
    -- the MSB of the Fraction is a "1" in a Signaling NAN, and is a
    -- "0" in a quiet NAN.
    return result;
  end function nanfp;
  function qnanfp (
    constant exponent_width : NATURAL := float_exponent_width;  -- exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- fraction
    return float is
    variable result : float (exponent_width downto -fraction_width) :=
      (others => '0');                  -- zero
  begin
    result (exponent_width-1 downto 0) := (others => '1');
    -- Exponent all "1"
    result (-fraction_width)           := '1';  -- LSB of Fraction "1"
    -- (Could have been any bit)
    return result;
  end function qnanfp;
  function pos_inffp (
    constant exponent_width : NATURAL := float_exponent_width;  -- exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- fraction
    return float is
    variable result : float (exponent_width downto -fraction_width) :=
      (others => '0');                  -- zero
  begin
    result (exponent_width-1 downto 0) := (others => '1');  -- Exponent all "1"
    return result;
  end function pos_inffp;
  function neg_inffp (
    constant exponent_width : NATURAL := float_exponent_width;  -- exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- fraction
    return float is
    variable result : float (exponent_width downto -fraction_width) :=
      (others => '0');                  -- zero
  begin
    result (exponent_width downto 0) := (others => '1');    -- top bits all "1"
    return result;
  end function neg_inffp;
  function neg_zerofp (
    constant exponent_width : NATURAL := float_exponent_width;  -- exponent
    constant fraction_width : NATURAL := float_fraction_width)  -- fraction
    return float is
    variable result : float (exponent_width downto -fraction_width) :=
      (others => '0');                  -- zero
  begin
    result (exponent_width) := '1';
    return result;
  end function neg_zerofp;
  -- size_res versions
  function zerofp (
    size_res : float)                   -- variable is only use for sizing
    return float is
  begin
    return zerofp (
      exponent_width => size_res'high,
      fraction_width => -size_res'low);
  end function zerofp;
  function nanfp (
    size_res : float)                   -- variable is only use for sizing
    return float is
  begin
    return nanfp (
      exponent_width => size_res'high,
      fraction_width => -size_res'low);
  end function nanfp;
  function qnanfp (
    size_res : float)                   -- variable is only use for sizing
    return float is
  begin
    return qnanfp (
      exponent_width => size_res'high,
      fraction_width => -size_res'low);
  end function qnanfp;
  function pos_inffp (
    size_res : float)                   -- variable is only use for sizing
    return float is
  begin
    return pos_inffp (
      exponent_width => size_res'high,
      fraction_width => -size_res'low);
  end function pos_inffp;
  function neg_inffp (
    size_res : float)                   -- variable is only use for sizing
    return float is
  begin
    return neg_inffp (
      exponent_width => size_res'high,
      fraction_width => -size_res'low);
  end function neg_inffp;
  function neg_zerofp (
    size_res : float)                   -- variable is only use for sizing
    return float is
  begin
    return neg_zerofp (
      exponent_width => size_res'high,
      fraction_width => -size_res'low);
  end function neg_zerofp;

-- rtl_synthesis off
  -- synthesis translate_off
  -- purpose: writes float into a line (NOTE changed basetype)
  type MVL9plus is ('U', 'X', '0', '1', 'Z', 'W', 'L', 'H', '-', error);
  type char_indexed_by_MVL9 is array (STD_ULOGIC) of CHARACTER;
  type MVL9_indexed_by_char is array (CHARACTER) of STD_ULOGIC;
  type MVL9plus_indexed_by_char is array (CHARACTER) of MVL9plus;

  constant MVL9_to_char : char_indexed_by_MVL9 := "UX01ZWLH-";
  constant char_to_MVL9 : MVL9_indexed_by_char :=
    ('U' => 'U', 'X' => 'X', '0' => '0', '1' => '1', 'Z' => 'Z',
     'W' => 'W', 'L' => 'L', 'H' => 'H', '-' => '-', others => 'U');
  constant char_to_MVL9plus : MVL9plus_indexed_by_char :=
    ('U' => 'U', 'X' => 'X', '0' => '0', '1' => '1', 'Z' => 'Z',
     'W' => 'W', 'L' => 'L', 'H' => 'H', '-' => '-', others => error);

  -- %%% Remove the following lines for inclution in VHDL-200x-ft
  constant NUS : STRING(2 to 1) := (others => ' ');  -- NULL array
  function justify (
    value     : STRING;
    justified : SIDE  := right;
    field     : width := 0)
    return STRING is
    constant VAL_LEN : INTEGER             := value'length;
    variable result  : STRING (1 to field) := (others => ' ');
  begin  -- function justify
    -- return value if field is too small
    if VAL_LEN >= field then
      return value;
    end if;
    if justified = left then
      result(1 to VAL_LEN) := value;
    elsif justified = right then
      result(field - VAL_LEN + 1 to field) := value;
    end if;
    return result;
  end function justify;
  -------------------------------------------------------------------    
  -- TO_HSTRING
  -------------------------------------------------------------------   
  function to_hstring (
    value     : STD_LOGIC_VECTOR;
    justified : SIDE  := right;
    field     : width := 0
    ) return STRING is
    constant ne     : INTEGER := (value'length+3)/4;
    variable pad    : STD_LOGIC_VECTOR(0 to (ne*4 - value'length) - 1);
    variable ivalue : STD_LOGIC_VECTOR(0 to ne*4 - 1);
    variable result : STRING(1 to ne);
    variable quad   : STD_LOGIC_VECTOR(0 to 3);
  begin
    if value'length < 1 then
      return NUS;
    else
      if value (value'left) = 'Z' then
        pad := (others => 'Z');
      else
        pad := (others => '0');
      end if;
      ivalue := pad & value;
      for i in 0 to ne-1 loop
        quad := To_X01Z(ivalue(4*i to 4*i+3));
        case quad is
          when x"0"   => result(i+1) := '0';
          when x"1"   => result(i+1) := '1';
          when x"2"   => result(i+1) := '2';
          when x"3"   => result(i+1) := '3';
          when x"4"   => result(i+1) := '4';
          when x"5"   => result(i+1) := '5';
          when x"6"   => result(i+1) := '6';
          when x"7"   => result(i+1) := '7';
          when x"8"   => result(i+1) := '8';
          when x"9"   => result(i+1) := '9';
          when x"A"   => result(i+1) := 'A';
          when x"B"   => result(i+1) := 'B';
          when x"C"   => result(i+1) := 'C';
          when x"D"   => result(i+1) := 'D';
          when x"E"   => result(i+1) := 'E';
          when x"F"   => result(i+1) := 'F';
          when "ZZZZ" => result(i+1) := 'Z';
          when others => result(i+1) := 'X';
        end case;
      end loop;
      return justify(result, justified, field);
    end if;
  end function to_hstring;

  -------------------------------------------------------------------    
  -- TO_OSTRING
  -------------------------------------------------------------------   
  function to_ostring (
    value     : STD_LOGIC_VECTOR;
    justified : SIDE  := right;
    field     : width := 0
    ) return STRING is
    constant ne     : INTEGER := (value'length+2)/3;
    variable pad    : STD_LOGIC_VECTOR(0 to (ne*3 - value'length) - 1);
    variable ivalue : STD_LOGIC_VECTOR(0 to ne*3 - 1);
    variable result : STRING(1 to ne);
    variable tri    : STD_LOGIC_VECTOR(0 to 2);
  begin
    if value'length < 1 then
      return NUS;
    else
      if value (value'left) = 'Z' then
        pad := (others => 'Z');
      else
        pad := (others => '0');
      end if;
      ivalue := pad & value;
      for i in 0 to ne-1 loop
        tri := To_X01Z(ivalue(3*i to 3*i+2));
        case tri is
          when o"0"   => result(i+1) := '0';
          when o"1"   => result(i+1) := '1';
          when o"2"   => result(i+1) := '2';
          when o"3"   => result(i+1) := '3';
          when o"4"   => result(i+1) := '4';
          when o"5"   => result(i+1) := '5';
          when o"6"   => result(i+1) := '6';
          when o"7"   => result(i+1) := '7';
          when "ZZZ"  => result(i+1) := 'Z';
          when others => result(i+1) := 'X';
        end case;
      end loop;
      return justify(result, justified, field);
    end if;
  end function to_ostring;
  -- %%% end remove lines

  procedure write (
    L         : inout LINE;             -- input line
    VALUE     : in    float;            -- floating point input
    JUSTIFIED : in    SIDE  := right;
    FIELD     : in    WIDTH := 0) is
    variable s     : STRING(1 to value'high - value'low +3);
    variable sindx : INTEGER;
  begin  -- function write
    s(1)  := MVL9_to_char(STD_ULOGIC(VALUE(VALUE'high)));
    s(2)  := ':';
    sindx := 3;
    for i in VALUE'high-1 downto 0 loop
      s(sindx) := MVL9_to_char(STD_ULOGIC(VALUE(i)));
      sindx    := sindx + 1;
    end loop;
    s(sindx) := ':';
    sindx    := sindx + 1;
    for i in -1 downto VALUE'low loop
      s(sindx) := MVL9_to_char(STD_ULOGIC(VALUE(i)));
      sindx    := sindx + 1;
    end loop;
    write(L, s, JUSTIFIED, FIELD);
  end procedure write;

  procedure READ(L : inout LINE; VALUE : out float) is
    -- Possible data:  0:0000:0000000
    --                 000000000000
    variable c      : CHARACTER;
    variable readOk : BOOLEAN;
    variable i      : INTEGER;          -- index variable
  begin  -- READ
    loop                                -- skip white space
      read(l, c, readOk);
      exit when ((readOk = false) or ((c /= ' ') and (c /= CR) and (c /= HT)));
    end loop;
    for i in value'high downto value'low loop
      value(i) := 'X';
    end loop;
    i := value'high;
    readloop : loop
      if readOk = false then            -- Bail out if there was a bad read
        report "FLOAT_GENERIC_PKG.READ(float): "
          & "Error end of file encountered.";
        return;
      elsif c = ' ' or c = CR or c = HT then  -- reading done.
        if (i /= value'low) then
          report "FLOAT_GENERIC_PKG.READ(float): "
            & "Warning: Value truncated.";
          return;
        end if;
      elsif c = ':' or c = '.' then    -- seperator, ignore
        if not (i = -1 or i = value'high-1) then
          report "FLOAT_GENERIC_PKG.READ(float):  "
            & "Warning: Seperator point does not match number format: '"
            & c & "' ecountered at location " & INTEGER'image(i) & ".";
        end if;
      elsif (char_to_MVL9plus(c) = error) then
        report "FLOAT_GENERIC_PKG.READ(float): "
          & "Error: Character '" & c & "' read, expected STD_ULOGIC literal.";
        return;
      else
        value (i) := char_to_MVL9(c);
        i         := i - 1;
        if i < value'low then
          return;
        end if;
      end if;
      read(l, c, readOk);
    end loop readloop;
  end procedure READ;

  procedure READ(L : inout LINE; VALUE : out float; GOOD : out BOOLEAN) is
    -- Possible data:  0:0000:0000000
    --                 000000000000
    variable c      : CHARACTER;
    variable i      : INTEGER;          -- index variable
    variable readOk : BOOLEAN;
  begin  -- READ
    loop                                -- skip white space
      read(l, c, readOk);
      exit when ((readOk = false) or ((c /= ' ') and (c /= CR) and (c /= HT)));
    end loop;
    for i in value'high downto value'low loop
      value(i) := 'X';
    end loop;
    i    := value'high;
    good := true;
    readloop : loop
      if readOk = false then            -- Bail out if there was a bad read
        good := false;
        return;
      elsif c = ' ' or c = CR or c = HT then  -- reading done
        good := false;
        return;
      elsif c = ':' or c = '.' then    -- seperator, ignore
        good := (i = -1 or i = value'high-1);
      elsif (char_to_MVL9plus(c) = error) then
        good := false;
        return;
      else
        value (i) := char_to_MVL9(c);
        i         := i - 1;
        if i < value'low then
          return;
        end if;
      end if;
      read(l, c, readOk);
    end loop readloop;
  end procedure READ;

  procedure owrite (
    L         : inout LINE;             -- access type (pointer)
    VALUE     : in    float;            -- value to write
    JUSTIFIED : in    SIDE  := right;   -- which side to justify text
    FIELD     : in    WIDTH := 0) is    -- width of field
  begin
    write (L         => L,
           VALUE     => to_ostring(VALUE),
           JUSTIFIED => JUSTIFIED,
           FIELD     => FIELD);
  end procedure owrite;

  procedure OREAD(L : inout LINE; VALUE : out float) is
    constant ne     : INTEGER := ((value'length+2)/3) * 3;  -- pad
    variable slv    : STD_LOGIC_VECTOR (ne-1 downto 0);     -- slv
    variable dummy  : CHARACTER;        -- to read the "."
    variable igood  : BOOLEAN;
    variable nybble : STD_LOGIC_VECTOR (2 downto 0);        -- 3 bits
    variable i      : INTEGER;
  begin
    OREAD (L     => L,
           VALUE => nybble,
           good  => igood);
    assert (igood)
      report "FLOAT_GENERIC_PKG.OREAD: Failed to skip white space " & L.all
      severity error;
    i                     := ne-1 - 3;  -- Top - 3
    slv (ne-1 downto i+1) := nybble;
    while (i /= -1) and igood and L.all'length /= 0 loop
      if (L.all(1) = '.') or (L.all(1) = ':') then
        read (L, dummy);
      else
        OREAD (L     => L,
               VALUE => nybble,
               good  => igood);        
        assert (igood)
          report "FLOAT_GENERIC_PKG.OREAD: Failed to read the string " & L.all
          severity error;
        slv (i downto i-2) := nybble;
        i                  := i - 3;
      end if;
    end loop;
    assert igood and                    -- We did not get another error
      (i = -1) and                      -- We read everything, and high bits 0
      (or_reducex(slv(ne-1 downto VALUE'high-VALUE'low+1)) = '0')
      report "FLOAT_GENERIC_PKG.OREAD: Vector truncated."
      severity error;
    value := to_float (slv(VALUE'high-VALUE'low downto 0),
                       value'high, -value'low);
  end procedure OREAD;

  procedure OREAD(L : inout LINE; VALUE : out float; GOOD : out BOOLEAN) is
    constant ne     : INTEGER := ((value'length+2)/3) * 3;  -- pad
    variable slv    : STD_LOGIC_VECTOR (ne-1 downto 0);     -- slv
    variable dummy  : CHARACTER;        -- to read the "."
    variable igood  : BOOLEAN;
    variable nybble : STD_LOGIC_VECTOR (2 downto 0);        -- 3 bits
    variable i      : INTEGER;
  begin
    OREAD (L     => L,
           VALUE => nybble,
           good  => igood);
    i                     := ne-1 - 3;  -- Top - 3
    slv (ne-1 downto i+1) := nybble;
    while (i /= -1) and igood and L.all'length /= 0 loop
      if (L.all(1) = '.') or (L.all(1) = ':') then
        read (L, dummy, igood);
      else
        OREAD (L     => L,
               VALUE => nybble,
               good  => igood);        
        slv (i downto i-2) := nybble;
        i                  := i - 3;
      end if;
    end loop;
    good := igood and                   -- We did not get another error
            (i = -1) and                -- We read everything, and high bits 0
            (or_reducex(slv(ne-1 downto VALUE'high-VALUE'low+1)) = '0');
    value := to_float (slv(VALUE'high-VALUE'low downto 0),
                       value'high, -value'low);
  end procedure OREAD;

  procedure hwrite (
    L         : inout LINE;             -- access type (pointer)
    VALUE     : in    float;            -- value to write
    JUSTIFIED : in    SIDE  := right;   -- which side to justify text
    FIELD     : in    WIDTH := 0) is    -- width of field
  begin
    write (L         => L,
           VALUE     => to_hstring(VALUE),
           JUSTIFIED => JUSTIFIED,
           FIELD     => FIELD);
  end procedure hwrite;

  procedure HREAD(L : inout LINE; VALUE : out float) is
    constant ne     : INTEGER := ((value'length+3)/4) * 4;  -- pad
    variable slv    : STD_LOGIC_VECTOR (ne-1 downto 0);     -- slv
    variable dummy  : CHARACTER;        -- to read the "."
    variable igood  : BOOLEAN;
    variable nybble : STD_LOGIC_VECTOR (3 downto 0);        -- 4 bits
    variable i      : INTEGER;
  begin
    HREAD (L     => L,
           VALUE => nybble,
           good  => igood);
    assert (igood)
      report "FLOAT_GENERIC_PKG.HREAD: Failed to skip white space " & L.all
      severity error;
    i                      := ne - 1 - 4;                   -- Top - 4
    slv (ne -1 downto i+1) := nybble;
    while (i /= -1) and igood and L.all'length /= 0 loop
      if (L.all(1) = '.') or (L.all(1) = ':') then
        read (L, dummy);
      else
        HREAD (L     => L,
               VALUE => nybble,
               good  => igood);        
        assert (igood)
          report "FLOAT_GENERIC_PKG.HREAD: Failed to read the string " & L.all
          severity error;
        slv (i downto i-3) := nybble;
        i                  := i - 4;
      end if;
    end loop;
    assert igood and                    -- We did not get another error
      (i = -1) and                      -- We read everything
      (or_reducex(slv(ne-1 downto VALUE'high-VALUE'low+1)) = '0')
      report "FLOAT_GENERIC_PKG.HREAD: Vector truncated."
      severity error;
    value := to_float (slv(VALUE'high-VALUE'low downto 0),
                       value'high, -value'low);
  end procedure HREAD;

  procedure HREAD(L : inout LINE; VALUE : out float; GOOD : out BOOLEAN) is
    constant ne     : INTEGER := ((value'length+3)/4) * 4;  -- pad
    variable slv    : STD_LOGIC_VECTOR (ne-1 downto 0);     -- slv
    variable dummy  : CHARACTER;        -- to read the "."
    variable igood  : BOOLEAN;
    variable nybble : STD_LOGIC_VECTOR (3 downto 0);        -- 4 bits
    variable i      : INTEGER;
  begin
    HREAD (L     => L,
           VALUE => nybble,
           good  => igood);
    i                     := ne - 1 - 4;                    -- Top - 4
    slv (ne-1 downto i+1) := nybble;
    while (i /= -1) and igood and L.all'length /= 0 loop
      if (L.all(1) = '.') or (L.all(1) = ':') then
        read (L, dummy, igood);
      else
        HREAD (L     => L,
               VALUE => nybble,
               good  => igood);        
        slv (i downto i-3) := nybble;
        i                  := i - 4;
      end if;
    end loop;
    good := igood and                   -- We did not get another error
            (i = -1) and                -- We read everything, and high bits 0
            (or_reducex(slv(ne-1 downto VALUE'high-VALUE'low+1)) = '0');
    value := to_float (slv(VALUE'high-VALUE'low downto 0),
                       value'high, -value'low);
  end procedure HREAD;

  function to_string (
    value     : float;
    justified : SIDE  := right;
    field     : width := 0
    ) return STRING is
    variable s     : STRING(1 to value'high - value'low +3);
    variable sindx : INTEGER;
  begin  -- function write
    s(1)  := MVL9_to_char(STD_ULOGIC(VALUE(VALUE'high)));
    s(2)  := ':';
    sindx := 3;
    for i in VALUE'high-1 downto 0 loop
      s(sindx) := MVL9_to_char(STD_ULOGIC(VALUE(i)));
      sindx    := sindx + 1;
    end loop;
    s(sindx) := ':';
    sindx    := sindx + 1;
    for i in -1 downto VALUE'low loop
      s(sindx) := MVL9_to_char(STD_ULOGIC(VALUE(i)));
      sindx    := sindx + 1;
    end loop;
    return justify (s, JUSTIFIED, FIELD);
  end function to_string;

  function to_hstring (
    value     : float;
    justified : SIDE  := right;
    field     : width := 0
    ) return STRING is
    variable slv : STD_LOGIC_VECTOR (value'length-1 downto 0);
  begin
    floop : for i in slv'range loop
      slv(i) := to_X01Z (value(i + value'low));
    end loop floop;
    return to_hstring (slv, justified, field);
  end function to_hstring;

  function to_ostring (
    value     : float;
    justified : SIDE  := right;
    field     : width := 0
    ) return STRING is
    variable slv : STD_LOGIC_VECTOR (value'length-1 downto 0);
  begin
    floop : for i in slv'range loop
      slv(i) := to_X01Z (value(i + value'low));
    end loop floop;
    return to_ostring (slv, justified, field);
  end function to_ostring;

  function from_string (
    bstring                 : STRING;   -- binary string
    constant exponent_width : NATURAL := float_exponent_width;
    constant fraction_width : NATURAL := float_fraction_width)
    return float is
    variable result : float (exponent_width downto -fraction_width);
    variable L      : LINE;
    variable good   : BOOLEAN;
  begin
    L := new STRING'(bstring);
    read (L, result, good);
    deallocate (L);
    assert (good)
      report "FLOAT_GENERIC_PKG.from_string: Bad string " & bstring
      severity error;
    return result;
  end function from_string;

  function from_ostring (
    ostring                 : STRING;   -- Octal string
    constant exponent_width : NATURAL := float_exponent_width;
    constant fraction_width : NATURAL := float_fraction_width)
    return float is
    variable result : float (exponent_width downto -fraction_width);
    variable L      : LINE;
    variable good   : BOOLEAN;
  begin
    L := new STRING'(ostring);
    oread (L, result, good);
    deallocate (L);
    assert (good)
      report "FLOAT_GENERIC_PKG.from_ostring: Bad string " & ostring
      severity error;
    return result;
  end function from_ostring;

  function from_hstring (
    hstring                 : STRING;   -- hex string
    constant exponent_width : NATURAL := float_exponent_width;
    constant fraction_width : NATURAL := float_fraction_width)
    return float is
    variable result : float (exponent_width downto -fraction_width);
    variable L      : LINE;
    variable good   : BOOLEAN;
  begin
    L := new STRING'(hstring);
    hread (L, result, good);
    deallocate (L);
    assert (good)
      report "FLOAT_GENERIC_PKG.from_hstring: Bad string " & hstring
      severity error;
    return result;
  end function from_hstring;

  function from_string (
    bstring  : STRING;                  -- binary string
    size_res : float)                   -- used for sizing only 
    return float is
  begin
    return from_string (bstring        => bstring,
                        exponent_width => size_res'high,
                        fraction_width => -size_res'low);
  end function from_string;

  function from_ostring (
    ostring  : STRING;                  -- Octal string
    size_res : float)                   -- used for sizing only 
    return float is
  begin
    return from_ostring (ostring        => ostring,
                         exponent_width => size_res'high,
                         fraction_width => -size_res'low);
  end function from_ostring;

  function from_hstring (
    hstring  : STRING;                  -- hex string
    size_res : float)                   -- used for sizing only 
    return float is
  begin
    return from_hstring (hstring        => hstring,
                         exponent_width => size_res'high,
                         fraction_width => -size_res'low);
  end function from_hstring;
  -- synthesis translate_on
-- rtl_synthesis on
  function to_StdLogicVector (arg : float) return STD_LOGIC_VECTOR is
  begin
    return to_slv (arg);
  end function to_StdLogicVector;

  function to_Std_Logic_Vector (arg : float) return std_logic_vector is
  begin
    return to_slv (arg);
  end function to_Std_Logic_Vector;

  function to_StdULogicVector (arg : float) return STD_ULOGIC_VECTOR is
  begin
    return to_sulv (arg);
  end function to_StdULogicVector;

  function to_Std_ULogic_Vector (arg : float) return std_ulogic_vector is
  begin
    return to_sulv (arg);
  end function to_Std_ULogic_Vector;
end package body float_pkg;

-- XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
>>>>>>> d68cfb566fed6f983427010d388a4e39e9131875
