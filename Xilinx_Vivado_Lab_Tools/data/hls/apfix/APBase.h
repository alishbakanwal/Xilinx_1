#ifndef HLS_APBASE_H
#define HLS_APBASE_H

#ifdef __linux__
#define DllExport
#else
#define DllExport  __declspec( dllexport ) 
#endif

#include <string>
#include <cstring>
#include <sstream>
#include <limits>

// Select 8, 16, 32 and 64 bit signed and unsigned integers in
// different platforms
#ifdef RDIPF_win
#if _MSC_VER <= 1500
typedef __int8 int8_t;
typedef unsigned __int8 uint8_t;
typedef __int16 int16_t;
typedef unsigned __int16 uint16_t;
typedef __int32 int32_t;
typedef unsigned __int32 uint32_t;
typedef __int64 int64_t;
typedef unsigned __int64 uint64_t;
#else
#include <stdint.h>
#endif
typedef unsigned __int64 ap_ulong;
typedef signed   __int64 ap_slong;
#else
#include <stdint.h>
typedef unsigned long long ap_ulong;
typedef signed   long long ap_slong;
#endif

namespace hls {

///  Macros to find maximum, minimum and absolute values
#define F_AP_MAX(a,b) ((a) > (b) ? (a) : (b))
#define F_AP_MIN(a,b) ((a) < (b) ? (a) : (b))
#define F_AP_ABS(a)   ((a)>=0 ? (a):-(a))

///  Maximum size of words supported
#ifndef F_AP_INT_MAX_W
#define F_AP_INT_MAX_W 1024
#endif
#define BIT_WIDTH_UPPER_LIMIT (1 << 15)
#if F_AP_INT_MAX_W > BIT_WIDTH_UPPER_LIMIT
#error "Bitwidth exceeds 32768 (1 << 15), the maximum allowed value"
#endif
#define MAX_MODE(BITS) ((BITS + 1023) / 1024)

///  Bits available in single word
#define F_AP_BITS_PER_WORD 64

#define WCOUNT(a) (a + F_AP_BITS_PER_WORD-1) / F_AP_BITS_PER_WORD

enum APFixQMode : uint8_t {
   F_AP_RND,         ///  rounding to plus infinity
   F_AP_RND_ZERO,    ///  rounding to zero
   F_AP_RND_MIN_INF, ///  rounding to minus infinity
   F_AP_RND_INF,     ///  rounding to infinity
   F_AP_RND_CONV,    ///  convergent rounding
   F_AP_TRN,         ///  truncation
   F_AP_TRN_ZERO     ///  truncation to zero
};
enum APFixOMode : uint8_t {
   F_AP_SAT,         ///  saturation
   F_AP_SAT_ZERO,    ///  saturation to zero
   F_AP_SAT_SYM,     ///  symmetrical saturation
   F_AP_WRAP,        ///  wrap-around (*)
   F_AP_WRAP_SM      ///  sign magnitude wrap-around (*)
};

/// Forward Declarations
class APBit;
class APRange;
class APConcat;

class APFixBase;
class APFixRange;
class APFixBit;

// *****************************************************************************
// class APBase: HLS arbitrary precision integer class
//
/// APBase - This class represents arbitrary precision constant integral
/// values. It is a replacement for common case unsigned integer type like
/// "unsigned", "unsigned long" or "uint64_t", but also allows non-byte-width
/// integer sizes and large integer value types such as 3-bits, 15-bits, or more
/// than 64-bits of precision. APBase provides a variety of arithmetic
/// operators and methods to manipulate integer values of any bit-width.
/// It supports both the typical integer arithmetic and comparison operations
/// as well as bitwise
///
/// The class has several invariants worth noting:
///   * All bit, byte, and word positions are zero-based.
///   * Once the bit width is set, it doesn't change except by the Resize,
///     Truncate, SignExtend, or ZeroExtend operations.
///   * The value is stored canonically as an unsigned value. For operations
///     where it makes a difference, there are both signed and unsigned variants
///     of the operation. For example, sdiv and udiv. However, because the bit
///     widths must be the same, operations such as Mul and Add produce the same
///     results regardless of whether the values are interpreted as signed or
///     not.
///   * In general, the class tries to follow the style of computation that LLVM
///     uses in its IR. This simplifies its use for LLVM.
///
/// @brief Class for arbitrary precision integers.
// *****************************************************************************
class DllExport APBase {

#ifdef RDIPF_win
#pragma warning( disable : 4521 4522 )
#endif

public:
   ///  64-bit data is used to store internal values
   typedef uint64_t ValueT;

   ///  Public Constructors
   APBase();
   APBase(const uint16_t bitwidth, const bool sign, const char *val);
   APBase(const uint16_t bitwidth, const bool sign, const char *val, int rd);
   APBase(const APRange &ref);
   APBase(const uint16_t bitwidth, const bool sign, const APRange &ref);
   APBase(const APBit &ref);
   APBase(const uint16_t bitwidth, const bool sign, const APBit &ref);
   APBase(const APConcat &ref);
   APBase(const uint16_t bitwidth, const bool sign, const APConcat &ref);
   APBase(const APFixRange &val);
   APBase(const uint16_t bitwidth, const bool sign, const APFixRange &val);
   APBase(const APFixBit &val);
   APBase(const uint16_t bitwidth, const bool sign, const APFixBit &val);
   APBase(const uint16_t bitwidth, const bool sign, const APBase &that);
   APBase(const uint16_t bitwidth, const bool sign);

#define CTOR(TYPE, SIGNED)                                                      \
   APBase(const uint16_t bitwidth, const bool sign, TYPE val,                   \
          bool isSigned=SIGNED);
   CTOR(bool, false)
   CTOR(signed char, true)
   CTOR(unsigned char, false)
   CTOR(signed short, true)
   CTOR(unsigned short, false)
   CTOR(signed int, true)
   CTOR(unsigned int, false)
   CTOR(signed long, true)
   CTOR(unsigned long, false)
   CTOR(ap_ulong, false)
   CTOR(ap_slong, true)
   CTOR(float, false)
   CTOR(double, false)
#undef CTOR

   APBase(const APBase &that);
   APBase(APBase &&that);

   /// Destructor
   ~APBase();

   /// Data attributes getters
   const uint16_t &getBitWidth() const;
   uint16_t length() const;
   uint16_t getNumWords() const;
   bool getSign() const;
   bool sign_value() const;

   APBase clone() const;

   /// Value getter and setter
   const ValueT &get_val(void) const;
   const ValueT &get_pVal(int index) const;
   const ValueT *get_pVal() const;
   const APBase &read() const;

   ValueT &get_pVal(int index);
   ValueT *get_pVal();

   void set_val(const ValueT &value);
   void set_pVal(int i, const ValueT &value);
   void write(const APBase &op2);
   void set(const APBase &val);

   /// Data type Converters
   bool to_bool() const;
   int to_uchar()  const;
   int to_char()   const;
   int to_ushort() const;
   int to_short()  const;
   int to_int()    const;
   long to_long()  const;
   double to_double() const;
   unsigned long to_ulong() const;
   int64_t to_int64()       const;
   unsigned to_uint()       const;
   uint64_t to_uint64()     const;
   std::string to_string(uint8_t radix = 2, bool sign = false) const;

   ///  Value testing APIs
   bool isSingleWord() const;
   bool iszero () const;
   bool isNegative() const;
   bool isPositive() const;
   bool isStrictlyPositive() const;
   bool isAllOnesValue() const;
   bool isMaxValue() const;
   bool isMaxSignedValue() const;
   bool isMinValue() const;
   bool isMinSignedValue() const;

   /// Utilities for bit level operations
   void clear();
   APBase &clear(uint16_t bitPosition);
   void clearUnusedBits(void);
   void set (int i, bool v);
   APBase &set(uint16_t bitPosition);
   void set();
   bool get (int i) const;
   APBase &flip();
   APBase &flip(uint16_t bitPosition);
   void set_bit (int i, bool v);

   bool get_bit (int i) const;
   APBase getLoBits(uint16_t numBits) const;
   APBase getHiBits(uint16_t numBits) const;
   uint16_t countLeadingZeros() const;
   uint16_t countLeadingOnes() const;
   uint16_t countTrailingZeros() const;

   APBase &operator = (const APBase &RHS);
   APBase &operator = (const APFixRange &val);
   APBase &operator = (const APFixBit &val);

   ///  Arithmetic assignment operator overloading
   APBase &operator &= (const APBase &RHS);
   APBase &operator |= (const APBase &RHS);
   APBase &operator ^= (const APBase &RHS);
   APBase &operator += (const APBase &RHS);
   APBase &operator -= (const APBase &RHS);
   APBase &operator *= (const APBase &RHS);
   APBase &operator /= (const APBase &RHS);
   APBase &operator %= (const APBase &RHS);

   ///  Arithmetic operator overloading
   APBase operator | (const APBase &RHS) const;
   APBase operator & (const APBase &RHS) const;
   APBase operator ^ (const APBase &RHS) const;
   APBase operator + (const APBase &RHS) const;
   APBase operator - (const APBase &RHS) const;
   APBase operator * (const APBase &RHS) const;
   APBase operator / (const APBase &RHS) const;
   APBase operator % (const APBase &RHS) const;

   ///  Logical operator overloading
   APBase operator << (const int op) const;
   APBase operator << (const bool op) const;
   APBase operator << (const signed char op) const;
   APBase operator << (const unsigned char op) const;
   APBase operator << (const short op) const;
   APBase operator << (const unsigned short op) const;
   APBase operator << (const unsigned int op) const;
   APBase operator << (const long op) const;
   APBase operator << (const unsigned long op) const;
   APBase operator << (const unsigned long long op) const;
   APBase operator << (const long long op) const;
   APBase operator << (const float op) const;
   APBase operator << (const double op) const;
   APBase operator << (const APBase &op) const;
   APBase operator >> (const int op) const;
   APBase operator >> (const bool op) const;
   APBase operator >> (const signed char op) const;
   APBase operator >> (const unsigned char op) const;
   APBase operator >> (const short op) const;
   APBase operator >> (const unsigned short op) const;
   APBase operator >> (const unsigned int op) const;
   APBase operator >> (const long op) const;
   APBase operator >> (const unsigned long op) const;
   APBase operator >> (const unsigned long long op) const;
   APBase operator >> (const long long op) const;
   APBase operator >> (const float op) const;
   APBase operator >> (const double op) const;
   APBase operator >> (const APBase &op2) const;

   /// Shift assignment operator overloading
   APBase &operator >>=(const APBase &op);
   APBase &operator <<=(const APBase &op);

   /// Comparison operator overloading
   bool operator == (const APBase &op) const;
   bool operator != (const APBase &op) const;
   bool operator <= (const APBase &op) const;
   bool operator <  (const APBase &op) const;
   bool operator >= (const APBase &op) const;
   bool operator >  (const APBase &op) const;

   /// Bit and Part selection operator overloading
   APRange operator () (int high, int low) const;
   APRange operator () (const APBase &hiIdx, const APBase &loIdx) const;

   APRange range (int high, int low) const;
   APRange range (const APBase &hiIdx, const APBase &loIdx) const;

   APBit operator [] (uint16_t index);
   APBit operator [] (const APBase &index);
   bool  operator [] (const APBase &index) const;
   bool  operator [] (uint16_t bitPosition) const;

   APBit bit (int index);
   APBit bit (const APBase &index);
   bool  bit (const int index) const;
   bool  bit (const APBase &index) const;

   /// Concatenation operators
   APConcat concat(const APBase &a2) const;
   APConcat operator, (const APBase &a2) const;
   APConcat operator, (const APRange &a2) const;
   APConcat operator, (const APBit &a2) const;
   APConcat operator, (const APConcat &a2) const;
   APConcat operator, (const APFixRange &a2) const;
   APConcat operator, (const APFixBit &a2) const;

   /// Operator overloading
   const APBase operator++(int);
   APBase &operator++();
   const APBase operator--(int);
   APBase &operator--();

   APBase operator~() const;
   APBase operator-() const;
   bool   operator !() const;

   /// Utilities
   APBase And(const APBase &RHS) const;
   APBase Or (const APBase &RHS) const;
   APBase Xor(const APBase &RHS) const;
   APBase Mul(const APBase &RHS) const;
   APBase Add(const APBase &RHS) const;
   APBase Sub(const APBase &RHS) const;

   APBase ashr(uint32_t shiftAmt) const;
   APBase lshr(uint32_t shiftAmt) const;
   APBase shl (uint32_t shiftAmt) const;
   APBase rotl(uint32_t rotateAmt) const;
   APBase rotr(uint32_t rotateAmt) const;

   APBase udiv(const APBase &RHS) const;
   APBase sdiv(const APBase &RHS) const;
   APBase urem(const APBase &RHS) const;
   APBase urem(uint64_t RHS)      const;
   APBase srem(const APBase &RHS) const;
   APBase srem(int64_t RHS)       const;

   APBase sqrt() const;
   APBase abs() const;

   bool eq (const APBase &RHS) const;
   bool ne (const APBase &RHS)  const;
   bool ult(const APBase &RHS) const;
   bool ult(const ValueT RHS)  const;
   bool slt(const APBase &RHS) const;
   bool ule(const APBase &RHS) const;
   bool sle(const APBase &RHS) const;
   bool ugt(const APBase &RHS) const;
   bool sgt(const APBase &RHS) const;
   bool uge(const APBase &RHS) const;
   bool sge(const APBase &RHS) const;

   /// Advance value characterization APIs
   double roundToDouble(bool isSigned = false) const;
   double signedRoundToDouble() const;
   double bitsToDouble() const;
   float bitsToFloat() const;

   APBase &doubleToBits(double val);
   APBase &floatToBits(float val);

   /// Reduce operation
   bool and_reduce() const;
   bool nand_reduce() const;
   bool or_reduce() const;
   bool nor_reduce() const;
   bool xor_reduce() const;
   bool xnor_reduce() const;

   /// Resizing operation
   void truncate(const uint16_t bitwidth);
   void signExtend(const uint16_t bitwidth);
   void setBitWidth(const uint16_t bitwidth);
   void setSign(const bool sign);

private:
   ///Private members to hold word count, data width and sign attribute
   uint16_t m_wcount;
   uint16_t m_bitwidth;
   bool m_sign;

   /// Handle memory ownership : The to track heap memory allocation if any.
   /// Heap memory allocation is required only if bit-width > 64.
   enum : bool {
      StackValue,            /// Clean-up operation is not required
      HeapValue              /// required delete[] to free memory
   } m_valueSType;

   /// This is used to represent internal data.
   /// When the integer width <= 64, it uses m_val, otherwise it uses m_pVal.
   union DataU {
      ValueT m_val;    ///Used to store the <= 64 bits integer value
      ValueT *m_pVal;  ///Used to store the >64 bits integer value
   } m_dataU;

   /// Some of the constructor is used only internally for speed of construction
   /// of temporaries. It is unsafe for general use so it is not public.
   APBase(const uint16_t bitwidth, const bool sign,
          uint16_t numWords, const uint64_t bigVal[]);
   APBase(const uint16_t bitwidth, const bool sign,
          const std::string &val, uint8_t radix = 2);
   APBase(const uint16_t bitwidth, const bool sign,
          const char strStart[], uint16_t slen, uint8_t radix);

   /// Utilities related to memory management
   void report();
   void report(const uint16_t bitwidth);
   void initialize(const uint16_t bitwidth, const bool sign);
   void destroy();
   void resize(const uint16_t width);

   ValueT *get_value(void);
   const ValueT *get_value(void) const;

   /// Resizing operation used for m_sign bit extension
   void cpSext(const APBase &that);
   void cpZext(const APBase &that);
   void cpZextOrTrunc(const APBase &that);
   void cpSextOrTrunc(const APBase &that);

   void clearUnusedBitsToZero(void);
   void clearUnusedBitsToOne(void);
   uint16_t get_excess_bits() const;
   uint64_t get_mask() const;

   uint16_t whichWord(uint16_t bitPosition) const;
   uint16_t whichBit(uint16_t bitPosition) const;
   uint64_t maskBit(uint16_t bitPosition) const;
   uint16_t getWord(uint16_t bitPosition) const;
   void fromString(const char *str, uint16_t slen, uint8_t radix);

   APBase &reverse ();
   void lrotate(int n);
   void rrotate(int n);

   void invert (int i);
   bool test (int i) const;

   uint16_t getActiveBits() const;
   uint64_t getZExtValue() const;
   int64_t  getSExtValue() const;
   uint16_t getBitsNeeded(const char *str, uint16_t slen, uint8_t radix);
   uint16_t countPopulation() const;

   std::string toString(uint8_t radix, bool wantSigned) const;
};

} //namespace hls
#endif ///  HLS_APBASE_H

