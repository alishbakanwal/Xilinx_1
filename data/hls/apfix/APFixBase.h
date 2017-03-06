// *****************************************************************************
// File: APFixBase.h
//
/// This file contains the definition of the APFixBase class.
// *****************************************************************************
#ifndef HLS_APFIX_BASE_H_
#define HLS_APFIX_BASE_H_

#ifdef __linux__
#define DllExport
#else
#define DllExport  __declspec( dllexport ) 
#endif


#include <math.h>
#include <sstream>
#include "APBase.h"

namespace hls {

//Macros for float and double standards
#define FLOAT_MAN 23
#define FLOAT_EXP 8
#define FLOAT_MAN_MASK 0x7fffff
#define DOUBLE_MAN 52
#define DOUBLE_EXP 11
#define DOUBLE_MAN_MASK 0x3fffffffffffffULL

#define BIAS(e) ((1ULL<<(e-1))-1)
#define FLOAT_BIAS BIAS(FLOAT_EXP)
#define DOUBLE_BIAS BIAS(DOUBLE_EXP)
#define F_APFX_IEEE_DOUBLE_E_MAX DOUBLE_BIAS
#define F_APFX_IEEE_DOUBLE_E_MIN (-DOUBLE_BIAS + 1)

///Forward Declarations
class APFixRange;
class APFixBit;

// *****************************************************************************
/// class APFixBase
//
/// THis is the APFixBase class. It represents arbitrary precision constant
/// integral values with decimal point. It is a replacement for common case
/// float and double with integer and fractional bits.  This class accepts total
/// width, integer width and sign to construct a fixed point data object
/// APFixBase provides a variety of arithmetic operators and methods to
/// manipulate integer values of any bit-width.  It supports both the typical
/// integer arithmetic and comparison operations as well as bitwise
// *****************************************************************************
class DllExport APFixBase {
#ifdef RDIPF_win
#pragma warning( disable : 4521 4522 )
#endif

private:
   APFixQMode m_qmode;
   APFixOMode m_omode;
   int16_t m_width;
   int16_t m_iwidth;
   APBase m_data;

public:
   /// Constructors
   APFixBase();
   APFixBase(const int16_t bitwidth, const int16_t int_width,
             const bool sign = true,
             APFixQMode q_mode = F_AP_TRN,
             APFixOMode o_mode = F_AP_WRAP);
   APFixBase(const int16_t bitwidth, const int16_t int_width,
             const bool sign, const APFixBase &op);

#define APF_CTOR_SPEC(C_TYPE)                                                   \
    inline APFixBase(const int16_t bitwidth, const int16_t int_width,           \
                     const bool sign, C_TYPE i_op):                             \
    m_data(bitwidth, sign, i_op)                                                \
    {                                                                           \
       m_width=bitwidth; m_iwidth = int_width;                                  \
       m_qmode = F_AP_TRN; m_omode = F_AP_WRAP;                                 \
       if (bitwidth != int_width)                                               \
         m_data = (APBase(bitwidth, sign, i_op) << (bitwidth-int_width));       \
    }

   APF_CTOR_SPEC(bool)
   APF_CTOR_SPEC(signed char)
   APF_CTOR_SPEC(unsigned char)
   APF_CTOR_SPEC(signed short)
   APF_CTOR_SPEC(unsigned short)
   APF_CTOR_SPEC(signed int)
   APF_CTOR_SPEC(unsigned int)
   APF_CTOR_SPEC(signed long)
   APF_CTOR_SPEC(unsigned long)
   APF_CTOR_SPEC(ap_slong)
   APF_CTOR_SPEC(ap_ulong)

#undef APF_CTOR_SPEC

   APFixBase(const int16_t bitwidth, const int16_t int_width,
             const bool sign, const APFixQMode q_mode,
             const APFixOMode o_mode, const APFixBase &op);
   APFixBase(const APBase &op);
   APFixBase(const int16_t bitwidth, const int16_t int_width,
             const bool sign, const APBase &op);
   APFixBase(const int16_t bitwidth, const int16_t int_width,
             const bool sign, const APFixQMode q_mode,
             const APFixOMode o_mode, const APBase &op);
   APFixBase(const int16_t bitwidth, const int16_t int_width,
             const bool sign, const char *val);
   APFixBase(const int16_t bitwidth, const int16_t int_width,
             const bool sign, const char *val, signed char radix);
   APFixBase(const APBit &op);
   APFixBase(const APRange &op);
   APFixBase(const APConcat &op);
   APFixBase(const APFixBit &op);
   APFixBase(const APFixRange &op);
   APFixBase(const int16_t bitwidth, const int16_t int_width,
             const bool sign, double d);
   APFixBase(const int16_t bitwidth, const int16_t int_width,
             const bool sign, const APFixQMode q_mode,
             const APFixOMode o_mode, double d);

   APFixBase(const APFixBase &op);
   APFixBase(APFixBase &&op);

   ~APFixBase();

   ///Get the internal data APBase as read only
   const APBase &get() const;

   ///Get the internal data APBase for write
   APBase &rawData();

   ///Data attributes getters
   int width () const;
   int iwidth () const;
   bool sign() const;
   APFixQMode q_mode () const;
   APFixOMode o_mode () const;

   ///Assign operator overloading
   APFixBase &operator = (const APFixBase &op);
   APFixBase &operator = (const APFixRange &op);
   APFixBase &operator = (const APFixBit &op);
   APFixBase &operator = (const double op);

   /// Operator to convert APFixBase to APBase
   operator APBase () const;

   /// Explicit data type conversion for C built-in supported type
   APFixBase &setInt64(int64_t v);
   APFixBase &setUInt64(uint64_t v);
   APFixBase &setBits(unsigned long long bv);

   double to_double() const;
   float to_float() const;
   unsigned char to_uint8() const;
   signed char to_int8() const;
   unsigned short to_uint16() const;
   signed short to_int16() const;
   unsigned int to_uint32() const;
   signed int to_int32() const;
   ap_ulong to_uint64() const;
   ap_slong to_int64() const;

   std::string to_string(uint8_t radix = 2) const;
   ap_slong bits_to_int64() const;
   ap_ulong bits_to_uint64() const;

   double bitsToDouble() const;
   float bitsToFloat() const;
   APFixBase &doubleToBits(double val);
   APFixBase &floatToBits(float val);

   /// Utilities
   int length() const;
   bool is_zero () const;
   bool is_neg () const;

   /// Arithmetic Binary operator overloading
   APFixBase operator * (const APFixBase &op2) const;
   APFixBase operator / (const APFixBase &op2) const;
   APFixBase operator + (const APFixBase &op2) const;
   APFixBase operator - (const APFixBase &op2) const;

   APFixBase operator & (const APFixBase &op2) const;
   APFixBase operator & (int op2) const;
   APFixBase operator | (const APFixBase &op2) const;
   APFixBase operator | (int op2) const;
   APFixBase operator ^ (const APFixBase &op2) const;
   APFixBase operator ^ (int op2) const;

   // Arithmetic assign operator overloading
   APFixBase &operator += (const APFixBase &op2);
   APFixBase &operator -= (const APFixBase &op2);
   APFixBase &operator &= (const APFixBase &op2);
   APFixBase &operator |= (const APFixBase &op2);
   APFixBase &operator ^= (const APFixBase &op2);
   APFixBase &operator *= (const APFixBase &op2);
   APFixBase &operator /= (const APFixBase &op2);
   APFixBase &operator += (const double op);

   /// Prefix increment, decrement operator overloading
   APFixBase &operator ++();
   APFixBase &operator --();

   /// Postfix increment, decrement operator overloading
   const APFixBase operator ++(int);
   const APFixBase operator --(int);

   /// Unary arithmetic operator overloading
   APFixBase operator +() const;
   APFixBase operator -() const;
   APFixBase getNeg() const;
   bool operator !() const;
   APFixBase operator ~() const;

   /// Shift operator overloading
   APFixBase operator << (int sh) const;
   APFixBase operator << (const APBase &op2) const;
   APFixBase operator << (unsigned int sh ) const;
   APFixBase operator >> (int sh) const;
   APFixBase operator >> (const APBase &op2) const;
   APFixBase operator >> (unsigned int sh) const;

   /// Shift(with APBase) operator overloading
   APFixBase &operator <<= (const APBase &op2);
   APFixBase &operator >>= (const APBase &op2);

   /// Shift(with APFixBase) operator overloading
   APFixBase operator  <<  (const APFixBase &op2) const;
   APFixBase &operator <<= (const APFixBase &op2);
   APFixBase operator  >>  (const APFixBase &op2) const;
   APFixBase &operator >>= (const APFixBase &op2);

   /// Comparisons operator overloading
   bool operator == (const APFixBase &op2) const;
   bool operator != (const APFixBase &op2) const;
   bool operator >  (const APFixBase &op2) const;
   bool operator <= (const APFixBase &op2) const;
   bool operator <  (const APFixBase &op2) const;
   bool operator >= (const APFixBase &op2) const;
   bool operator == (double d) const;
   bool operator != (double d) const;
   bool operator >  (double d) const;
   bool operator >= (double d) const;
   bool operator <  (double d) const;
   bool operator <= (double d) const;

   /// Bit and Slice Select
   APFixBit operator [] (unsigned int index);
   bool operator [] (unsigned int index) const;
   bool operator [] (const APBase &index) const;

   APFixRange operator () (int Hi, int Lo) const;
   APFixRange operator () (const APBase &HiIdx, const APBase &LoIdx) const;

   APFixBit bit(unsigned int index);
   APFixBit bit (const APBase &index);
   bool bit (unsigned int index) const;
   bool bit (const APBase &index) const;

   APFixBit get_bit(int index);
   APFixBit get_bit (const APBase &index);
   bool get_bit (int index) const;
   bool get_bit (const APBase &index) const;

   APFixRange range() const;
   APFixRange range(int Hi, int Lo) const;
   APFixRange range(const APBase &HiIdx, const APBase &LoIdx) const;

   void set (int i, bool v);
   APFixBase &set(uint16_t bitPosition);
   void set();

   APFixBase &clear(uint16_t bitPosition);
   void clear();

   void sign(bool s);
   APFixBase &setAttributes(const int16_t bitwidth,
                            const int16_t int_width,
                            const bool sign,
                            const APFixQMode q_mode = F_AP_TRN,
                            const APFixOMode o_mode = F_AP_WRAP);

   friend class APFixBit;
   friend class APFixRange;

private:

   void initialize(const int16_t bitwidth,
                   const int16_t int_width,
                   const bool sign,
                   const APFixQMode q_mode = F_AP_TRN,
                   const APFixOMode o_mode = F_AP_WRAP);

   void fromString(const std::string &val);
   void fromString(const std::string &val, unsigned char radix);
   void report();
   unsigned long long doubleToRawBits(double pf)const;
   double rawBitsToDouble(unsigned long long pi) const;
   float rawBitsToFloat(uint32_t pi) const;
   void overflow_adjust(bool underflow, bool overflow, bool lD, bool sign);
   bool quantization_adjust(bool qb, bool r, bool s);
   int countLeadingZeros();
   APBase to_ap_base(bool native = true) const;
   APFixBase lshift (int shift) const;
   APFixBase rshift (int shift) const;
   void from_double(double val);
};

}// namespace hls

#endif // ifndef HLS_APFIX_BASE_H_
