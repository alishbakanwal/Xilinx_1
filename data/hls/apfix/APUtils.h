
#ifndef HLS_APBASE_UTIL_H
#define HLS_APBASE_UTIL_H

#include "APBase.h"


// *****************************************************************************
// ApBaseUtil.h : The file contains hls::utilities namespace
//
/// This HEADER ONLY namespace contains inline utilities for AP datatype.
/// All the utilities are optimized for better performance.
/// Changing its implementation will have a big impact on the
/// APBase and APFix data type objects
//
// *****************************************************************************

namespace hls {
namespace utilities {

// *****************************************************************************
// min - Template utility to find minimum of two numbers
// *****************************************************************************
template <class Type>
Type inline min(Type a, Type b)
{
   return (a >= b) ? b : a;
}

// *****************************************************************************
// max - Template utility to find maximun of two numbers
// *****************************************************************************
template <class Type>
Type inline max(Type a, Type b)
{
   return (a >= b) ? a : b;
}

// *****************************************************************************
// Hi_32 - This function returns the high 32 bits of a 64 bit value.
// *****************************************************************************
inline uint32_t Hi_32(uint64_t Value)
{
   return static_cast<uint32_t>(Value >> 32);
}

// *****************************************************************************
// Lo_32 - This function returns the low 32 bits of a 64 bit value.
// *****************************************************************************
inline uint32_t Lo_32(uint64_t Value)
{
   return static_cast<uint32_t>(Value);
}

// *****************************************************************************
// isNegative - Check the APBase is positive or negative based on sign
// bit and sign mask
// *****************************************************************************
static inline bool isNegative(const APBase &a)
{
   if (a.getSign()) {
      const uint16_t wcount = a.getNumWords();
      const uint64_t sign_mask = 1ULL<<((a.getBitWidth() - 1) %
                                        F_AP_BITS_PER_WORD);
      return (sign_mask & a.get_pVal(wcount-1)) != 0;
   }
   return false;
}

// *****************************************************************************
// CountLeadingZeros_32 - this function performs the platform optimal form of
// counting the number of zeros from the most significant bit to the first one
// bit.  Ex. CountLeadingZeros_32(0x00F000FF) == 8.
// Returns 32 if the word is zero.
// *****************************************************************************
inline unsigned CountLeadingZeros_32(uint32_t Value)
{
   unsigned count; // result
#if __GNUC__ >= 4
   if (Value == 0) {
      return 32;
   }
   count = __builtin_clz(Value);
#else
   if (Value == 0) {
      return 32;
   }
   count = 0;
   // bisection method for count leading zeros
   for (unsigned Shift = 32 >> 1; Shift; Shift >>= 1) {
      uint32_t tmp = (Value) >> (Shift);
      if (tmp) {
         Value = tmp;
      } else {
         count |= Shift;
      }
   }
#endif
   return count;
}

// *****************************************************************************
// CountLeadingZeros_64 - This function performs the platform optimal form
// of counting the number of zeros from the most significant bit to the first
// one bit (64 bit edition.)
// Returns 64 if the word is zero.
// *****************************************************************************
inline unsigned CountLeadingZeros_64(uint64_t Value)
{
   unsigned count; // result
#if __GNUC__ >= 4
   if (!Value) {
      return 64;
   }
   count = __builtin_clzll(Value);
#else
   if (sizeof(long) == sizeof(int64_t)) {
      if (!Value) {
         return 64;
      }
      count = 0;
      // bisection method for count leading zeros
      for (unsigned Shift = 64 >> 1; Shift; Shift >>= 1) {
         uint64_t tmp = (Value) >> (Shift);
         if (tmp) {
            Value = tmp;
         } else {
            count |= Shift;
         }
      }
   } else {
      // get hi portion
      uint32_t Hi = Hi_32(Value);

      // if some bits in hi portion
      if (Hi) {
         // leading zeros in hi portion plus all bits in lo portion
         count = CountLeadingZeros_32(Hi);
      } else {
         // get lo portion
         uint32_t Lo = Lo_32(Value);
         // same as 32 bit value
         count = CountLeadingZeros_32(Lo)+32;
      }
   }
#endif
   return count;
}

// *****************************************************************************
// CountTrailingZeros_64 - This function performs the platform optimal form
// of counting the number of zeros from the least significant bit to the first
// one bit (64 bit edition.)
// Returns 64 if the word is zero.
// *****************************************************************************
inline unsigned CountTrailingZeros_64(uint64_t Value)
{
#if __GNUC__ >= 4
   return (Value != 0) ? __builtin_ctzll(Value) : 64;
#else
   static const unsigned Mod67Position[] = {
      64, 0, 1, 39, 2, 15, 40, 23, 3, 12, 16, 59, 41, 19, 24, 54,
      4, 64, 13, 10, 17, 62, 60, 28, 42, 30, 20, 51, 25, 44, 55,
      47, 5, 32, 65, 38, 14, 22, 11, 58, 18, 53, 63, 9, 61, 27,
      29, 50, 43, 46, 31, 37, 21, 57, 52, 8, 26, 49, 45, 36, 56,
      7, 48, 35, 6, 34, 33, 0
   };
   return Mod67Position[(uint64_t)(-(int64_t)Value & (int64_t)Value) % 67];
#endif
}

// *****************************************************************************
// CountPopulation_64 - this function counts the number of set bits in a value,
// (64 bit edition.)
// *****************************************************************************
inline unsigned CountPopulation_64(uint64_t Value)
{
#if __GNUC__ >= 4
   return __builtin_popcountll(Value);
#else
   uint64_t v = Value - (((Value) >> 1) & 0x5555555555555555ULL);
   v = (v & 0x3333333333333333ULL) + (((v) >> 2) & 0x3333333333333333ULL);
   v = (v + ((v) >> 4)) & 0x0F0F0F0F0F0F0F0FULL;
   return unsigned((uint64_t)(v * 0x0101010101010101ULL) >> 56);
#endif
}

// *****************************************************************************
// countLeadingOnes_64 - this function return leading number of ones
// it accepts 64 bit input and skip value
// (64 bit edition.)
// *****************************************************************************
static inline uint32_t countLeadingOnes_64(uint64_t __V, uint32_t skip)
{
   uint32_t count = 0;
   if (skip) {
      (__V) <<= (skip);
   }
   while (__V && (__V & (1ULL << 63))) {
      count++;
      (__V) <<= 1;
   }
   return count;
}

// *****************************************************************************
// oct2Bin - this function converts octal to binary format
// *****************************************************************************
static inline  std::string oct2Bin(char oct)
{
   switch (oct) {
      case '\0': {
            return "";
         }
      case '.': {
            return ".";
         }
      case '0': {
            return "000";
         }
      case '1': {
            return "001";
         }
      case '2': {
            return "010";
         }
      case '3': {
            return "011";
         }
      case '4': {
            return "100";
         }
      case '5': {
            return "101";
         }
      case '6': {
            return "110";
         }
      case '7': {
            return "111";
         }
   }

   //assert(0 && "Invalid character in digit string");
   return "";
}

// *****************************************************************************
// hex2Bin - this function converts hex to binary format
// *****************************************************************************
static inline  std::string hex2Bin(char hex)
{
   switch (hex) {
      case '\0': {
            return "";
         }
      case '.': {
            return ".";
         }
      case '0': {
            return "0000";
         }
      case '1': {
            return "0001";
         }
      case '2': {
            return "0010";
         }
      case '3': {
            return "0011";
         }
      case '4': {
            return "0100";
         }
      case '5': {
            return "0101";
         }
      case '6': {
            return "0110";
         }
      case '7': {
            return "0111";
         }
      case '8': {
            return "1000";
         }
      case '9': {
            return "1001";
         }
      case 'A':
      case 'a': {
            return "1010";
         }
      case 'B':
      case 'b': {
            return "1011";
         }
      case 'C':
      case 'c': {
            return "1100";
         }
      case 'D':
      case 'd': {
            return "1101";
         }
      case 'E':
      case 'e': {
            return "1110";
         }
      case 'F':
      case 'f': {
            return "1111";
         }
   }
   //assert(0 && "Invalid character in digit string");
   return "";
}

// *****************************************************************************
// decode_digit - this function decoded character value for the radix input
// *****************************************************************************
static inline  uint32_t decode_digit(char cdigit, int radix)
{
   uint32_t digit = 0;
   if (radix == 16) {
#define isxdigit(c)(((c) >= '0' && (c) <= '9') || ((c) >= 'a' && (c) <= 'f') || \
                    ((c) >= 'A' && (c) <= 'F'))
#define isdigit(c) ((c) >= '0' && (c) <= '9')
      //if (!isxdigit(cdigit))
      //  assert(0 && "Invalid hex digit in string");
      if (isdigit(cdigit)) {
         digit = cdigit - '0';
      } else if (cdigit >= 'a') {
         digit = cdigit - 'a' + 10;
      } else if (cdigit >= 'A') {
         digit = cdigit - 'A' + 10;
      }
   } else if (isdigit(cdigit)) {
      digit = cdigit - '0';
   }
#undef isxdigit
#undef isdigit
   return digit;
}

// *****************************************************************************
// parseString - Parse the input string for the radix
// *****************************************************************************
static inline std::string parseString(const std::string &input, int &radix)
{

   size_t len = input.length();
   if (len == 0) {
      return input;
   }

   size_t startPos = 0;
   // Trim white space
   while (input[startPos] == ' ' && startPos < len) {
      startPos++;
   }
   while (input[len-1] == ' ' && startPos < len) {
      len--;
   }

   std::string val = input.substr(startPos, len-startPos);
   len = val.length();
   startPos = 0;

   // If the length of the string is less than 2, then radix
   // is decimal and there is no exponent.
   if (len < 2) {
      return val;
   }

   bool isNegative = false;
   std::string ans;

   // First check to see if we start with a sign indicator
   if (val[0] == '-') {
      ans = "-";
      ++startPos;
      isNegative = true;
   } else if (val[0] == '+') {
      ++startPos;
   }

   if (len - startPos < 2) {
      return val;
   }

   if (val.substr(startPos, 2) == "0x" || val.substr(startPos, 2) == "0X") {
      // If we start with "0x", then the radix is hex.
      radix = 16;
      startPos += 2;
   } else if (val.substr(startPos, 2) == "0b"||val.substr(startPos,2) == "0B") {
      // If we start with "0b", then the radix is binary.
      radix = 2;
      startPos += 2;
   }
   if (val.substr(startPos, 2) == "0o" || val.substr(startPos, 2) == "0O") {
      // If we start with "0o", then the radix is octal.
      radix = 8;
      startPos += 2;
   }

   int exp = 0;
   if (radix == 10) {
      // If radix is decimal, then see if there is an
      // exponent indicator.
      size_t expPos = val.find('e');
      bool has_exponent = true;
      if (expPos == std::string::npos) {
         expPos = val.find('E');
      }
      if (expPos == std::string::npos) {
         // No exponent indicator, so the mantissa goes to the end.
         expPos = len;
         has_exponent = false;
      }

      ans += val.substr(startPos, expPos-startPos);
      if (has_exponent) {
         // Parse the exponent.
         std::istringstream   iss(val.substr(expPos+1, len-expPos-1));
         iss >> exp;
      }
   } else {
      // Check for a binary exponent indicator.
      size_t expPos = val.find('p');
      bool has_exponent = true;
      if (expPos == std::string::npos) {
         expPos = val.find('P');
      }
      if (expPos == std::string::npos) {
         // No exponent indicator, so the mantissa goes to the end.
         expPos = len;
         has_exponent = false;
      }

      //assert(startPos <= expPos);
      // Convert to binary as we go.
      for (size_t i=startPos; i<expPos; ++i) {
         if (radix == 16) {
            ans += hex2Bin(val[i]);
         } else if (radix == 8) {
            ans += oct2Bin(val[i]);
         } else {                    // radix == 2
            ans += val[i];
         }
      }
      // End in binary
      radix = 2;
      if (has_exponent) {
         // Parse the exponent.
         std::istringstream iss(val.substr(expPos+1, len-expPos-1));
         iss >> exp;
      }
   }
   if (exp == 0) {
      return ans;
   }

   size_t decPos = ans.find('.');
   if (decPos == std::string::npos) {
      decPos = ans.length();
   }
   if ((int) decPos + exp >= (int) ans.length()) {
      int i = decPos;
      for (; i< (int) ans.length()-1; ++i) {
         ans[i] = ans[i+1];
      }
      for (; i< (int) ans.length(); ++i) {
         ans[i] = '0';
      }
      for (; i< (int) decPos + exp; ++i) {
         ans += '0';
      }
      return ans;
   } else if ((int) decPos + exp < (int) isNegative) {
      std::string dupAns = "0.";
      if (ans[0] == '-') {
         dupAns = "-0.";
      }
      for (int i=0; i<isNegative-(int)decPos-exp; ++i) {
         dupAns += '0';
      }
      for (size_t i=isNegative; i< ans.length(); ++i)
         if (ans[i] != '.') {
            dupAns += ans[i];
         }
      return dupAns;
   }

   if (exp > 0)
      for (size_t i=decPos; i<decPos+exp; ++i) {
         ans[i] = ans[i+1];
      }
   else {
      if (decPos == ans.length()) {
         ans += ' ';
      }
      for (int i=decPos; i>(int)decPos+exp; --i) {
         ans[i] = ans[i-1];
      }
   }
   ans[decPos+exp] = '.';
   return ans;
}

// *****************************************************************************
// sub_1 - This function subtracts a single "digit" (64-bit word), y, from
// the multi-digit integer array, x[], propagating the borrowed 1 value until
// no further borrowing is needed or it runs out of "digits" in x.  The result
// is 1 if "borrowing" exhausted the digits in x, or 0 if x was not exhausted.
// In other words, if y > x then this function returns 1, otherwise 0.
// @returns the borrow out of the subtraction
// *****************************************************************************
inline bool sub_1(uint64_t x[], uint16_t len, uint64_t y)
{
   for (uint16_t i = 0; i < len; ++i) {
      uint64_t __X = x[i];
      x[i] -= y;
      if (y > __X) {
         y = 1;   // We have to "borrow 1" from next "digit"
      } else {
         y = 0;  // No need to borrow
         break;  // Remaining digits are unchanged so exit early
      }
   }
   return (y != 0);
}

// *****************************************************************************
// add_1 - This function adds a single "digit" integer, y, to the multiple
// "digit" integer array,  x[]. x[] is modified to reflect the addition and
// 1 is returned if there is a carry out, otherwise 0 is returned.
// @returns the carry of the addition.
// *****************************************************************************
static inline bool add_1(uint64_t dest[],uint64_t x[],uint16_t len,uint64_t y)
{
   for (uint16_t i = 0; i < len; ++i) {
      dest[i] = y + x[i];
      if (dest[i] < y) {
         y = 1;   // Carry one to next digit.
      } else {
         y = 0; // No need to carry so exit early
         break;
      }
   }
   return (y != 0);
}

// *****************************************************************************
// add - This function adds the integer array x to the integer array Y and
// places the result in dest.
// @returns the carry out from the addition
// @brief General addition of 64-bit integer arrays
// *****************************************************************************
static inline bool add(uint64_t *dest, const uint64_t *x, const uint64_t *y,
                       uint16_t destlen, uint16_t xlen, uint16_t ylen,
                       bool xsigned, bool ysigned)
{
   bool carry = false;
   uint16_t len = min(xlen, ylen);
   uint16_t i;
   for (i = 0; i< len && i < destlen; ++i) {
      uint64_t limit = min(x[i],y[i]);
      dest[i] = x[i] + y[i] + carry;
      carry = dest[i] < limit || (carry && dest[i] == limit);
   }
   if (xlen > ylen) {
      const uint64_t yext = ysigned && int64_t(y[ylen-1])<0 ? -1 : 0;
      for (i=ylen; i< xlen && i < destlen; i++) {
         uint64_t limit = min(x[i], yext);
         dest[i] = x[i] + yext + carry;
         carry = (dest[i] < limit)||(carry && dest[i] == x[i]);
      }
   } else if (ylen> xlen) {
      const uint64_t xext = xsigned && int64_t(x[xlen-1])<0 ? -1 : 0;
      for (i=xlen; i< ylen && i < destlen; i++) {
         uint64_t limit = min(xext, y[i]);
         dest[i] = xext + y[i] + carry;
         carry = (dest[i] < limit)||(carry && dest[i] == y[i]);
      }
   }
   return carry;
}

// *****************************************************************************
// @returns returns the borrow out.
// @brief Generalized subtraction of 64-bit integer arrays.
// *****************************************************************************
static inline bool sub(uint64_t *dest, const uint64_t *x, const uint64_t *y,
                       uint16_t destlen, uint16_t xlen, uint16_t ylen,
                       bool xsigned, bool ysigned)
{
   bool borrow = false;
   uint16_t i;
   uint16_t len = min(xlen, ylen);
   for (i = 0; i < len && i < destlen; ++i) {
      uint64_t x_tmp = borrow ? x[i] - 1 : x[i];
      borrow = y[i] > x_tmp || (borrow && x[i] == 0);
      dest[i] = x_tmp - y[i];
   }
   if (xlen > ylen) {
      const uint64_t yext = ysigned && int64_t(y[ylen-1])<0 ? -1 : 0;
      for (i=ylen; i< xlen && i < destlen; i++) {
         uint64_t x_tmp = borrow ? x[i] - 1 : x[i];
         borrow = yext > x_tmp || (borrow && x[i] == 0);
         dest[i] = x_tmp - yext;
      }
   } else if (ylen> xlen) {
      const uint64_t xext = xsigned && int64_t(x[xlen-1])<0 ? -1 : 0;
      for (i=xlen; i< ylen && i < destlen; i++) {
         uint64_t x_tmp = borrow ? xext - 1 : xext;
         borrow = y[i] > x_tmp || (borrow && xext==0);
         dest[i] = x_tmp - y[i];
      }
   }
   return borrow;
}

// *****************************************************************************
// Multiplies an integer array, x by a uint64_t integer and places the result
// into dest.
// @returns the carry out of the multiplication.
// @brief Multiply a multi-digit APBase by a single digit (64-bit)integer
// *****************************************************************************
static inline uint64_t mul_1(uint64_t dest[], const uint64_t x[],
                             uint16_t len, uint64_t y)
{
   // Split y into high 32-bit part (hy)  and low 32-bit part (ly)
   uint64_t ly = y & 0xffffffffULL, hy = (y) >> 32;
   uint64_t carry = 0;
   static const uint64_t two_power_32 = 1ULL << 32;
   // For each digit of x.
   for (uint16_t i = 0; i < len; ++i) {
      // Split x into high and low words
      uint64_t lx = x[i] & 0xffffffffULL;
      uint64_t hx = (x[i]) >> 32;
      // hasCarry - A flag to indicate if there is a carry to the next digit.
      // hasCarry == 0, no carry
      // hasCarry == 1, has carry
      // hasCarry == 2, no carry and the calculation result == 0.
      uint8_t hasCarry = 0;
      dest[i] = carry + lx * ly;
      // Determine if the add above introduces carry.
      hasCarry = (dest[i] < carry) ? 1 : 0;
      carry = hx * ly + ((dest[i]) >> 32) + (hasCarry ? two_power_32 : 0);
      // The upper limit of carry can be (2^32 - 1)(2^32 - 1) +
      // (2^32 - 1) + 2^32 = 2^64.
      hasCarry = (!carry && hasCarry) ? 1 : (!carry ? 2 : 0);

      carry += (lx * hy) & 0xffffffffULL;
      dest[i] = ((carry) << 32) | (dest[i] & 0xffffffffULL);
      carry = (((!carry && hasCarry != 2)||hasCarry == 1)?two_power_32 : 0) +
              ((carry) >> 32) + ((lx * hy) >> 32) + hx * hy;
   }
   return carry;
}

// *****************************************************************************
// Multiplies integer array x by integer array y and stores the result into
// the integer array dest. Note that dest's size must be >= xlen + ylen in order
// do a full precision computation. If it is not, then only the low-order words
// are returned.
// @brief Generalized multiplication of integer arrays.
// *****************************************************************************
static inline void mul(uint64_t dest[], const uint64_t x[], uint16_t xlen,
                       const uint64_t y[], uint16_t ylen, uint16_t destlen)
{

   if (1 == destlen) {
      mul_1(dest, x, xlen, y[0]);
   }

   if (xlen < destlen) {
      dest[xlen] = mul_1(dest, x, xlen, y[0]);
   }
   for (uint16_t i = 1; i < ylen; ++i) {
      uint64_t ly = y[i] & 0xffffffffULL, hy = (y[i]) >> 32;
      uint64_t carry = 0, lx = 0, hx = 0;
      for (uint16_t j = 0; j < xlen; ++j) {
         lx = x[j] & 0xffffffffULL;
         hx = (x[j]) >> 32;
         // hasCarry - A flag to indicate if has carry.
         // hasCarry == 0, no carry
         // hasCarry == 1, has carry
         // hasCarry == 2, no carry and the calculation result == 0.
         uint8_t hasCarry = 0;
         uint64_t resul = carry + lx * ly;
         hasCarry = (resul < carry) ? 1 : 0;
         carry = (hasCarry ? (1ULL << 32) : 0) + hx * ly + ((resul) >> 32);
         hasCarry = (!carry && hasCarry) ? 1 : (!carry ? 2 : 0);
         carry += (lx * hy) & 0xffffffffULL;
         resul = ((carry) << 32) | (resul & 0xffffffffULL);
         if (i+j < destlen) {
            dest[i+j] += resul;
         }
         carry = (((!carry && hasCarry != 2)||hasCarry==1)?(1ULL << 32) : 0)+
                 ((carry) >> 32) + (dest[i+j] < resul ? 1 : 0) +
                 ((lx * hy) >> 32) + hx * hy;
      }
      if (i+xlen < destlen) {
         dest[i+xlen] = carry;
      }
   }
}

// *****************************************************************************
// Multiplies integer array x by integer array y and add the result into
// the integer array dest. Note that dest's size must be >= xlen + ylen in order
// do a full precision computation. If it is not, then only the low-order words
// are returned.
// @brief Multiplication of integer arrays and its result get added to dest.
// dest = dst + (x*y);
// Used in Matrix Multiplication
// *****************************************************************************
static inline void mul_add(uint64_t dest[], const uint64_t x[], uint16_t xlen,
                           const uint64_t y[], uint16_t ylen,
                           uint16_t destlen, bool sign)
{

   ///Get the copy of dest
   uint64_t *temp = new uint64_t[destlen];
   memcpy(temp, dest, destlen*sizeof(uint64_t));
   /// perform dest = x * y
   mul(dest, x, xlen, y, ylen, destlen);
   /// perform dest = dest + (x*y)
   add(dest, dest, temp, destlen, destlen, destlen, sign, sign);
   delete[] temp;
}

// *****************************************************************************
// Implementation of Knuth's Algorithm D (Division of non-negative integers)
// from "Art of Computer Programming, Volume 2", section 4.3.1, p. 272. The
// variables here have the same names as in the algorithm. Comments explain
// the algorithm and any deviation from it.
// *****************************************************************************
static inline void KnuthDiv(uint32_t *u, uint32_t *v, uint32_t *q, uint32_t *r,
                            uint32_t m, uint32_t n)
{
   //assert(u && "Must provide dividend");
   //assert(v && "Must provide divisor");
   //assert(q && "Must provide quotient");
   //assert(u != v && u != q && v != q && "Must us different memory");
   //assert(n>1 && "n must be > 1");

   // Knuth uses the value b as the base of the number system. In our case b
   // is 2^31 so we just set it to -1u.
   uint64_t b = uint64_t(1) << 32;

   // D1. [Normalize.] Set d = b / (v[n-1] + 1) and multiply all the digits of
   // u and v by d. Note that we have taken Knuth's advice here to use a power
   // of 2 value for d such that d * v[n-1] >= b/2 (b is the base). A power of
   // 2 allows us to shift instead of multiply and it is easy to determine the
   // shift amount from the leading zeros.  We are basically normalizing the u
   // and v so that its high bits are shifted to the top of v's range without
   // overflow. Note that this can require an extra word in u so that u must
   // be of length m+n+1.
   uint32_t shift = CountLeadingZeros_32(v[n-1]);
   uint32_t v_carry = 0;
   uint32_t u_carry = 0;
   if (shift) {
      for (uint32_t i = 0; i < m+n; ++i) {
         uint32_t u_tmp = (u[i]) >> (32 - shift);
         u[i] = ((u[i]) << (shift)) | u_carry;
         u_carry = u_tmp;
      }
      for (uint32_t i = 0; i < n; ++i) {
         uint32_t v_tmp = (v[i]) >> (32 - shift);
         v[i] = ((v[i]) << (shift)) | v_carry;
         v_carry = v_tmp;
      }
   }
   u[m+n] = u_carry;

   // D2. [Initialize j.]  Set j to m. This is the loop counter over the places
   int j = m;
   do {
      //DEBUG(cerr << "KnuthDiv: quotient digit #" << j << '\n');
      // D3. [Calculate q'.].
      //     Set qp = (u[j+n]*b + u[j+n-1]) / v[n-1]. (qp=qprime=q')
      //     Set rp = (u[j+n]*b + u[j+n-1]) % v[n-1]. (rp=rprime=r')
      // Now test if qp == b or qp*v[n-2] > b*rp + u[j+n-2]; if so, decrease
      // qp by 1, inrease rp by v[n-1], and repeat this test if rp < b.
      // The test on v[n-2] determines at high speed most of the cases in
      // which the trial value qp is one too large, and it eliminates all
      // cases where qp is two too large.
      uint64_t dividend = ((uint64_t(u[j+n]) << 32) + u[j+n-1]);
      //DEBUG(cerr << "KnuthDiv: dividend == " << dividend << '\n');
      uint64_t qp = dividend / v[n-1];
      uint64_t rp = dividend % v[n-1];
      if (qp == b || qp*v[n-2] > b*rp + u[j+n-2]) {
         qp--;
         rp += v[n-1];
         if (rp < b && (qp == b || qp*v[n-2] > b*rp + u[j+n-2])) {
            qp--;
         }
      }
      // D4. [Multiply and subtract.] Replace (u[j+n]u[j+n-1]...u[j]) with
      // (u[j+n]u[j+n-1]..u[j]) - qp * (v[n-1]...v[1]v[0]). This computation
      // consists of a simple multiplication by a one-place number,
      // combined with a subtraction.
      bool isNeg = false;
      for (uint16_t i = 0; i < n; ++i) {
         uint64_t u_tmp = uint64_t(u[j+i]) | ((uint64_t(u[j+i+1])) << 32);
         uint64_t subtrahend = uint64_t(qp) * uint64_t(v[i]);
         bool borrow = subtrahend > u_tmp;

         uint64_t result = u_tmp - subtrahend;
         uint16_t k = j + i;
         u[k++] = (uint32_t)(result & (b-1)); // subtract low word
         u[k++] = (uint32_t)((result) >> 32); // subtract high word
         while (borrow && k <= m+n) {         // deal with borrow to the left
            borrow = u[k] == 0;
            u[k]--;
            k++;
         }
         isNeg |= borrow;
      }
      // The digits (u[j+n]...u[j]) should be kept positive; if the result of
      // this step is actually negative, (u[j+n]...u[j]) should be left as the
      // true value plus b**(n+1), namely as the b's complement of
      // the true value, and a "borrow" to the left should be remembered.

      if (isNeg) {
         // true because b's complement is "complement + 1"
         bool carry = true;
         for (uint32_t i = 0; i <= m+n; ++i) {
            u[i] = ~u[i] + carry;       // b's complement
            carry = carry && u[i] == 0;
         }
      }

      // D5. [Test remainder.] Set q[j] = qp. If the result of step D4 was
      // negative, go to step D6; otherwise go on to step D7.
      q[j] = (uint32_t)qp;
      if (isNeg) {
         // D6. [Add back]. The probability that this step is necessary
         // is very small, on the order of only 2/b. Make sure that test data
         // accounts for this possibility. Decrease q[j] by 1
         q[j]--;
         // and add (0v[n-1]...v[1]v[0]) to (u[j+n]u[j+n-1]...u[j+1]u[j]).
         // A carry will occur to the left of u[j+n], and it should be
         // ignored since it cancels with the borrow that occurred in D4.
         bool carry = false;
         for (uint16_t i = 0; i < n; i++) {
            uint32_t limit = min(u[j+i],v[i]);
            u[j+i] += v[i] + carry;
            carry = u[j+i] < limit || (carry && u[j+i] == limit);
         }
         u[j+n] += carry;
      }
      // D7. [Loop on j.]  Decrease j by one. Now if j >= 0, go back to D3.
   } while (--j >= 0);

   // D8. [Unnormalize]. Now q[...] is the desired quotient, and the desired
   // remainder may be obtained by dividing u[...] by d. If r is non-null we
   // compute the remainder (urem uses this).
   if (r) {
      // The value d is expressed by the "shift" value above since we avoided
      // multiplication by d by using a shift left. So, all we have to do is
      // shift right here. In order to mak
      if (shift) {
         uint32_t carry = 0;
         for (int i = n-1; i >= 0; i--) {
            r[i] = ((u[i]) >> (shift)) | carry;
            carry = (u[i]) << (32 - shift);
         }
      } else {
         for (int i = n-1; i >= 0; i--) {
            r[i] = u[i];
         }
      }
   }
}

// *****************************************************************************
// Divide LHS APBase and RHS APBase and
// calculate quotient and remainder of it
// Uses Knuth's Algorithm D (Division of non-negative integers) for bigger
// word lengths
// *****************************************************************************
static inline void divide(const APBase &LHS, uint16_t lhsWords,
                          const APBase &RHS, uint16_t rhsWords,
                          APBase *Quotient, APBase *Remainder)
{
   //assert(lhsWords >= rhsWords && "Fractional result");

   // First, compose the values into an array of 32-bit words instead of
   // 64-bit words. This is a necessity of both the "short division" algorithm
   // and the the Knuth "classical algorithm" which requires there to be native
   // operations for +, -, and * on an m bit value with an m*2 bit result. We
   // can't use 64-bit operands here because we don't have native results of
   // 128-bits. Furthremore, casting the 64-bit values to 32-bit values won't
   // work on large-endian machines.

   uint64_t mask = ~0ull >> (sizeof(uint32_t)*8);
   uint16_t n = rhsWords * 2;
   uint16_t m = (lhsWords * 2) - n;

   // Allocate space for the temporary values we need either on the stack, if
   // it will fit, or on the heap if it won't.
   uint32_t SPACE[128];
   uint32_t *__U = 0;
   uint32_t *__V = 0;
   uint32_t *__Q = 0;
   uint32_t *__R = 0;
   if ((Remainder?4:3)*n+2*m+1 <= 128) {
      __U = &SPACE[0];
      __V = &SPACE[m+n+1];
      __Q = &SPACE[(m+n+1) + n];
      if (Remainder) {
         __R = &SPACE[(m+n+1) + n + (m+n)];
      }
   } else {
      __U = new uint32_t[m + n + 1];
      __V = new uint32_t[n];
      __Q = new uint32_t[m+n];
      if (Remainder) {
         __R = new uint32_t[n];
      }
   }

   // Initialize the dividend
   memset(__U, 0, (m+n+1)*sizeof(uint32_t));
   for (unsigned i = 0; i < lhsWords; ++i) {
      uint64_t tmp = LHS.get_pVal(i);
      __U[i * 2] = (uint32_t)(tmp & mask);
      __U[i * 2 + 1] = (tmp) >> (sizeof(uint32_t)*8);
   }
   // this extra word is for "spill" in the Knuth algorithm.
   __U[m+n] = 0;

   // Initialize the divisor
   memset(__V, 0, (n)*sizeof(uint32_t));
   for (unsigned i = 0; i < rhsWords; ++i) {
      uint64_t tmp = RHS.get_pVal(i);
      __V[i * 2] = (uint32_t)(tmp & mask);
      __V[i * 2 + 1] = (tmp) >> (sizeof(uint32_t)*8);
   }

   // initialize the quotient and remainder
   memset(__Q, 0, (m+n) * sizeof(uint32_t));
   if (Remainder) {
      memset(__R, 0, n * sizeof(uint32_t));
   }

   // Now, adjust m and n for the Knuth division. n is the number of words in
   // the divisor. m is the number of words by which the dividend exceeds the
   // divisor (i.e. m+n is the length of the dividend). These sizes must not
   // contain any zero words or the Knuth algorithm fails.
   for (unsigned i = n; i > 0 && __V[i-1] == 0; i--) {
      n--;
      m++;
   }
   for (unsigned i = m+n; i > 0 && __U[i-1] == 0; i--) {
      m--;
   }

   // If we're left with only a single word for the divisor, Knuth doesn't work
   // so we implement the short division algorithm here. This is much simpler
   // and faster because we are certain that we can divide a 64-bit quantity
   // by a 32-bit quantity at hardware speed and short division is simply a
   // series of such operations. This is just like doing short division but we
   // are using base 2^32 instead of base 10.
   //assert(n != 0 && "Divide by zero?");
   if (n == 1) {
      uint32_t divisor = __V[0];
      uint32_t remainder = 0;
      for (int i = m+n-1; i >= 0; i--) {
         uint64_t partial_dividend = (uint64_t(remainder)) << 32 | __U[i];
         if (partial_dividend == 0) {
            __Q[i] = 0;
            remainder = 0;
         } else if (partial_dividend < divisor) {
            __Q[i] = 0;
            remainder = (uint32_t)partial_dividend;
         } else if (partial_dividend == divisor) {
            __Q[i] = 1;
            remainder = 0;
         } else {
            __Q[i] = (uint32_t)(partial_dividend / divisor);
            remainder = (uint32_t)(partial_dividend - (__Q[i] * divisor));
         }
      }
      if (__R) {
         __R[0] = remainder;
      }
   } else {
      // Now we're ready to invoke the Knuth classical divide algorithm.
      // In this case n > 1.
      KnuthDiv(__U, __V, __Q, __R, m, n);
   }

   // If the caller wants the quotient
   if (Quotient) {
      // Set up the Quotient value's memory.
      if (Quotient->getBitWidth() != LHS.getBitWidth()) {
         if (Quotient->isSingleWord()) {
            Quotient->set_val(0);
         }
      } else {
         Quotient->clear();
      }

      // The quotient is in Q. Reconstitute the quotient into Quotient's low
      // order words.
      if (lhsWords == 1) {
         uint64_t tmp =
            uint64_t(__Q[0])|((uint64_t(__Q[1]))<<(F_AP_BITS_PER_WORD / 2));
         Quotient->set_val(tmp);
      } else {
         //assert(!Quotient->isSingleWord());
         for (unsigned i = 0; i < lhsWords; ++i)
            Quotient->set_pVal(i,
                               uint64_t(__Q[i*2]) |
                               (uint64_t(__Q[i*2+1])) << (F_AP_BITS_PER_WORD / 2));
      }
      Quotient->clearUnusedBits();
   }

   // If the caller wants the remainder
   if (Remainder) {
      // Set up the Remainder value's memory.
      if (Remainder->getBitWidth() != RHS.getBitWidth()) {
         if (Remainder->isSingleWord()) {
            Remainder->set_val(0);
         }
      } else {
         Remainder->clear();
      }

      // Remainder is in R. Reconstitute the remainder into Remainder's low
      // order words.
      if (rhsWords == 1) {
         uint64_t tmp =
            uint64_t(__R[0])|((uint64_t(__R[1]))<<(F_AP_BITS_PER_WORD / 2));
         Remainder->set_val(tmp);
      } else {
         //assert(!Remainder->isSingleWord());
         for (unsigned i = 0; i < rhsWords; ++i)
            Remainder->set_pVal(i,
                                uint64_t(__R[i*2])|
                                ((uint64_t(__R[i*2+1]))<<(F_AP_BITS_PER_WORD / 2)));
      }
      Remainder->clearUnusedBits();
   }

   // Clean up the memory we allocated.
   if (__U != &SPACE[0]) {
      delete [] __U;
      delete [] __V;
      delete [] __Q;
      delete [] __R;
   }
}

// *****************************************************************************
// Divide LHS APBase and RHS 64 bit data and
// calculate quotient and remainder of it
// Uses Knuth's Algorithm D (Division of non-negative integers) for bigger
// word lengths
// *****************************************************************************
static inline void divide(const APBase &LHS, uint16_t lhsWords,
                          uint64_t RHS,
                          APBase *Quotient, APBase *Remainder)
{
   uint16_t rhsWords=1;
   //assert(lhsWords >= rhsWords && "Fractional result");
   // First, compose the values into an array of 32-bit words instead of
   // 64-bit words. This is a necessity of both the "short division" algorithm
   // and the the Knuth "classical algorithm" which requires there to be native
   // operations for +, -, and * on an m bit value with an m*2 bit result. We
   // can't use 64-bit operands here because we don't have native results of
   // 128-bits. Furthermore, casting the 64-bit values to 32-bit values won't
   // work on large-endian machines.
   uint64_t mask = ~0ull >> (sizeof(uint32_t)*8);
   uint32_t n = 2;
   uint32_t m = (lhsWords * 2) - n;

   // Allocate space for the temporary values we need either on the stack, if
   // it will fit, or on the heap if it won't.
   uint32_t SPACE[128];
   uint32_t *__U = 0;
   uint32_t *__V = 0;
   uint32_t *__Q = 0;
   uint32_t *__R = 0;
   if ((Remainder?4:3)*n+2*m+1 <= 128) {
      __U = &SPACE[0];
      __V = &SPACE[m+n+1];
      __Q = &SPACE[(m+n+1) + n];
      if (Remainder) {
         __R = &SPACE[(m+n+1) + n + (m+n)];
      }
   } else {
      __U = new uint32_t[m + n + 1];
      __V = new uint32_t[n];
      __Q = new uint32_t[m+n];
      if (Remainder) {
         __R = new uint32_t[n];
      }
   }

   // Initialize the dividend
   memset(__U, 0, (m+n+1)*sizeof(uint32_t));
   for (unsigned i = 0; i < lhsWords; ++i) {
      uint64_t tmp = LHS.get_pVal(i);
      __U[i * 2] = tmp & mask;
      __U[i * 2 + 1] = (tmp) >> (sizeof(uint32_t)*8);
   }
   __U[m+n] = 0; // this extra word is for "spill" in the Knuth algorithm.

   // Initialize the divisor
   memset(__V, 0, (n)*sizeof(uint32_t));
   __V[0] = RHS & mask;
   __V[1] = (RHS) >> (sizeof(uint32_t)*8);

   // initialize the quotient and remainder
   memset(__Q, 0, (m+n) * sizeof(uint32_t));
   if (Remainder) {
      memset(__R, 0, n * sizeof(uint32_t));
   }

   // Now, adjust m and n for the Knuth division. n is the number of words in
   // the divisor. m is the number of words by which the dividend exceeds the
   // divisor (i.e. m+n is the length of the dividend). These sizes must not
   // contain any zero words or the Knuth algorithm fails.
   for (unsigned i = n; i > 0 && __V[i-1] == 0; i--) {
      n--;
      m++;
   }
   for (unsigned i = m+n; i > 0 && __U[i-1] == 0; i--) {
      m--;
   }

   // If we're left with only a single word for the divisor, Knuth doesn't work
   // so we implement the short division algorithm here. This is much simpler
   // and faster because we are certain that we can divide a 64-bit quantity
   // by a 32-bit quantity at hardware speed and short division is simply a
   // series of such operations. This is just like doing short division but we
   // are using base 2^32 instead of base 10.
   //assert(n != 0 && "Divide by zero?");
   if (n == 1) {
      uint32_t divisor = __V[0];
      uint32_t remainder = 0;
      for (int i = m+n-1; i >= 0; i--) {
         uint64_t partial_dividend = (uint64_t(remainder)) << 32 | __U[i];
         if (partial_dividend == 0) {
            __Q[i] = 0;
            remainder = 0;
         } else if (partial_dividend < divisor) {
            __Q[i] = 0;
            remainder = partial_dividend;
         } else if (partial_dividend == divisor) {
            __Q[i] = 1;
            remainder = 0;
         } else {
            __Q[i] = partial_dividend / divisor;
            remainder = partial_dividend - (__Q[i] * divisor);
         }
      }
      if (__R) {
         __R[0] = remainder;
      }
   } else {
      // Now we're ready to invoke the Knuth classical divide algorithm.
      // In this case n > 1.
      KnuthDiv(__U, __V, __Q, __R, m, n);
   }

   // If the caller wants the quotient
   if (Quotient) {
      // Set up the Quotient value's memory.
      if (Quotient->getBitWidth() != LHS.getBitWidth()) {
         if (Quotient->isSingleWord()) {
            Quotient->set_val(0);
         }
      } else {
         Quotient->clear();
      }

      // The quotient is in Q. Reconstitute the quotient into Quotient's low
      // order words.
      if (lhsWords == 1) {
         uint64_t tmp =
            uint64_t(__Q[0])|((uint64_t(__Q[1]))<<(F_AP_BITS_PER_WORD / 2));
         Quotient->set_val(tmp);
      } else {
         //assert(!Quotient->isSingleWord()");
         for (unsigned i = 0; i < lhsWords; ++i)
            Quotient->set_pVal(i,
                               uint64_t(__Q[i*2]) |
                               ((uint64_t(__Q[i*2+1])) << (F_AP_BITS_PER_WORD / 2)));
      }
      Quotient->clearUnusedBits();
   }

   // If the caller wants the remainder
   if (Remainder) {
      // Set up the Remainder value's memory.
      if (Remainder->getBitWidth() != 64 /* RHS.getBitWidth() */) {
         if (Remainder->isSingleWord()) {
            Remainder->set_val(0);
         }
      } else {
         Remainder->clear();
      }

      // Remainder is in __R. Reconstitute the remainder into Remainder's low
      // order words.
      if (rhsWords == 1) {
         uint64_t tmp =
            uint64_t(__R[0]) | ((uint64_t(__R[1])) << (F_AP_BITS_PER_WORD / 2));
         Remainder->set_val(tmp);
      } else {
         //assert(!Remainder->isSingleWord());
         //Coverity - Dead code
         //for (unsigned i = 0; i < rhsWords; ++i)
         //    Remainder->set_pVal(i,
         //        uint64_t(__R[i*2]) |
         //       ((uint64_t(__R[i*2+1])) << (F_AP_BITS_PER_WORD / 2)));
      }
      Remainder->clearUnusedBits();
   }

   // Clean up the memory we allocated.
   if (__U != &SPACE[0]) {
      delete [] __U;
      delete [] __V;
      delete [] __Q;
      delete [] __R;
   }
}

// *****************************************************************************
// @brief Logical right-shift function.
// *****************************************************************************
inline APBase lshr(const APBase &LHS, uint32_t shiftAmt)
{
   return LHS.lshr(shiftAmt);
}

// *****************************************************************************
// Left-shift the APBase by shiftAmt.
// @brief Left-shift function.
// *****************************************************************************
inline APBase shl(const APBase &LHS, uint32_t shiftAmt)
{
   return LHS.shl(shiftAmt);
}

// *****************************************************************************
// @brief Logical equality operator.
// *****************************************************************************
inline bool operator==(uint64_t V1, const APBase &V2)
{
   return V2.to_uint64() == V1;
}

// *****************************************************************************
// @brief Logical not equality operator.
// *****************************************************************************
inline bool operator!=(uint64_t V1, const APBase &V2)
{
   return V2.to_uint64() != V1;
}

// *****************************************************************************
// @brief get the index-th element from APBase object
// *****************************************************************************
inline bool get(const APBase &a, const int index)
{
   const uint64_t mask=1ULL << (index&0x3f);
   return ((mask & a.get_pVal(index>>6)) != 0);
}

// *****************************************************************************
// @brief set all bits from mark1 to mark2 of the APBase object
// *****************************************************************************
inline void set(APBase &a, const int mark1, const int mark2 )
{

   const uint16_t lsb_word = mark2 /F_AP_BITS_PER_WORD;
   const uint16_t msb_word = mark1 / F_AP_BITS_PER_WORD;
   const uint16_t msb = mark1 % F_AP_BITS_PER_WORD;
   const uint16_t lsb = mark2 % F_AP_BITS_PER_WORD;

   if (msb_word == lsb_word) {
      const uint64_t mask = ~0ULL >> (lsb)<<(F_AP_BITS_PER_WORD-msb+lsb-1) >>
                            (F_AP_BITS_PER_WORD-msb-1);
      a.get_pVal(msb_word) |= mask;
   } else {
      const uint64_t lsb_mask = ~0ULL >> (lsb) << (lsb);
      const uint64_t msb_mask = ~0ULL << (F_AP_BITS_PER_WORD-msb-1) >>
                                (F_AP_BITS_PER_WORD-msb-1);

      a.get_pVal(lsb_word) |= lsb_mask;
      for (int i=lsb_word+1; i<msb_word; i++) {
         a.set_pVal(i, ~0ULL);
      }
      a.get_pVal(msb_word) |= msb_mask;
   }
   a.clearUnusedBits();
}

// *****************************************************************************
// @brief clear all bits from mark1 to mark2 of the APBase object
// *****************************************************************************
inline void clear(APBase &a, const int mark1, const int mark2)
{
   const uint16_t lsb_word = mark2 /F_AP_BITS_PER_WORD;
   const uint16_t msb_word = mark1 / F_AP_BITS_PER_WORD;
   const uint16_t msb = mark1 % F_AP_BITS_PER_WORD;
   const uint16_t lsb = mark2 % F_AP_BITS_PER_WORD;

   if (msb_word == lsb_word) {
      const uint64_t mask = ~(~0ULL >> (lsb)<<(F_AP_BITS_PER_WORD-msb+lsb-1)>>
                              (F_AP_BITS_PER_WORD-msb-1));
      a.get_pVal(msb_word) &= mask;
   } else {
      const uint64_t lsb_mask = ~(~0ULL >> (lsb) << (lsb));
      const uint64_t msb_mask = ~(~0ULL << (F_AP_BITS_PER_WORD-msb-1)>>
                                  (F_AP_BITS_PER_WORD-msb-1));
      a.get_pVal(lsb_word) &=lsb_mask;
      for (int i=lsb_word+1; i<msb_word; i++) {
         a.get_pVal(i)=0;
      }
      a.get_pVal(msb_word) &= msb_mask;
   }
   a.clearUnusedBits();
}

// *****************************************************************************
// @brief set index-th bit of the APBase object
// *****************************************************************************
inline void set(APBase &a, const int index)
{
   uint16_t word = index/F_AP_BITS_PER_WORD;
   const uint64_t mask=1ULL << (index%F_AP_BITS_PER_WORD);
   a.get_pVal(word) |= mask;
   a.clearUnusedBits();
}

// *****************************************************************************
// @brief clear index-th bit of the APBase object
// *****************************************************************************
inline void clear(APBase &a, const int index)
{
   uint16_t word = index/F_AP_BITS_PER_WORD;
   const uint64_t mask=~(1ULL << (index%F_AP_BITS_PER_WORD));
   a.get_pVal(word) &= mask;
   a.clearUnusedBits();
}

} // namespace utilities
} // namespace hls

#endif // HLS_APBASE_UTIL_H
