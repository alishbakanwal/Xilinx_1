// *****************************************************************************
// File: APFixBaseExt.h
//
/// This file contains the definition of the APFixBit, and APFixRange classes.
// *****************************************************************************
#ifndef HLS_APFIX_BASE_EXT_H_
#define HLS_APFIX_BASE_EXT_H_

#ifdef __linux__
#define DllExport
#else
#define DllExport  __declspec( dllexport ) 
#endif

#include <stdio.h>
#include <iostream>

#include "APBase.h"
#include "APFixBase.h"

namespace hls {

// *****************************************************************************
// class APFixBit
//
/// This is the APFixBit class; it helps to slice bit in APFixBase value used to
/// select a bit from APFixBase Proxy class, which allows bit selection to be
/// used as rvalue(for reading) and lvalue(for writing)
///
/// Object bit selection
/// TODO - We can use m_bv as object reference to avoid data copy
// *****************************************************************************
class DllExport APFixBit {
#ifdef RDIPF_win
#pragma warning( disable : 4521 4522 )
#endif

public:
   APFixBase &m_bv;
   int m_index;

   APFixBit(const APFixBit &ref);
   APFixBit(APFixBase &bv, int index=0);

   operator bool() const;
   APFixBit &operator = (unsigned long long val);
   APFixBit &operator = (const APBase &val);
   APFixBit &operator = (const APFixBit &val);
   APFixBit &operator = (const APBit &val);
   APFixBit &operator = (const APRange &val);
   APFixBit &operator = (const APFixRange &val);
   APFixBit &operator = (const APConcat &val);
   APConcat operator, (const APBase &op);
   APConcat operator, (const APBit &op);
   APConcat operator, (const APRange &op);
   APConcat operator, (const APConcat &op);
   APConcat operator, (const APFixRange &op);
   APConcat operator, (const APFixBit &op);
   bool operator == (const APFixBit &op);
   bool operator != (const APFixBit &op);
   bool operator ~ () const;
   int length() const;
   bool get();
   bool get() const;
   std::string to_string() const;
};

// *****************************************************************************
// class APFixRange
//
/// This is the APFixRange class; it helps to slice range in APFixBase value
/// used to slice APFixBase objects Proxy class, which allows part selection to
/// be used as rvalue(for reading) and lvalue(for writing)
///
/// Object Range for slicing.
/// TODO - We can use m_bv as object reference to avoid data copy
// *****************************************************************************
class DllExport APFixRange {
#ifdef RDIPF_win
#pragma warning( disable : 4521 4522 )
#endif

public:
   APFixBase &m_bv;
   int m_lIndex;
   int m_hIndex;

   APFixRange(const APFixRange &ref);
   APFixRange(APFixBase &bv, int h, int l);
   operator APBase () const;
   operator unsigned long long() const;
   APFixRange &operator =(const APBase &val);

#define ASSIGN_INT_TO_AF_RANGE(DATA_TYPE)                                       \
   APFixRange& operator = (const DATA_TYPE val);
   ASSIGN_INT_TO_AF_RANGE(char)
   ASSIGN_INT_TO_AF_RANGE(signed char)
   ASSIGN_INT_TO_AF_RANGE(short)
   ASSIGN_INT_TO_AF_RANGE(unsigned short)
   ASSIGN_INT_TO_AF_RANGE(int)
   ASSIGN_INT_TO_AF_RANGE(unsigned int)
   ASSIGN_INT_TO_AF_RANGE(long)
   ASSIGN_INT_TO_AF_RANGE(unsigned long)
   ASSIGN_INT_TO_AF_RANGE(long long)
   ASSIGN_INT_TO_AF_RANGE(unsigned long long)
#undef ASSIGN_INT_TO_AF_RANGE

   APFixRange &operator = (const APConcat &val);
   APFixRange &operator = (const APBit &val);
   APFixRange &operator = (const APRange &val);
   APFixRange &operator = (const APFixRange &val);
   APFixRange &operator = (const char *val);
   APFixRange &operator = (const APFixBase &val);
   bool operator == (const APRange &op2);
   bool operator != (const APRange &op2);
   bool operator >  (const APRange &op2);
   bool operator >= (const APRange &op2);
   bool operator <  (const APRange &op2);
   bool operator <= (const APRange &op2);
   bool operator == (const APFixRange &op2);
   bool operator != (const APFixRange &op2);
   bool operator >  (const APFixRange &op2);
   bool operator >= (const APFixRange &op2);
   bool operator <  (const APFixRange &op2);
   bool operator <= (const APFixRange &op2);

   void set(const APBase &val);
   APBase get() const;

   APConcat operator, (const APBase &op);
   APConcat operator, (const APBit &op);
   APConcat operator, (const APRange &op);
   APConcat operator, (const APConcat &op);
   APConcat operator, (const APFixRange &op);
   APConcat operator, (const APFixBit &op);

   int length() const;
   int to_int() const;
   unsigned int to_uint() const;
   long to_long() const;
   unsigned long to_ulong() const;
   ap_slong to_int64() const;
   ap_ulong to_uint64() const;
   std::string to_string(uint8_t radix=2) const;
};


void b_not(APFixBase &ret, const APFixBase &op);
void b_and(APFixBase &ret, const APFixBase &op1, const APFixBase &op2);
void b_or(APFixBase &ret, const APFixBase &op1, const APFixBase &op2);
void b_xor(APFixBase &ret, const APFixBase &op1, const APFixBase &op2);
void neg(APFixBase &ret, const APFixBase &op);
void lshift(APFixBase &ret, const APFixBase &op, int i);
void rshift(APFixBase &ret, const APFixBase &op, int i);
std::string scientificFormat(std::string &input);
std::string reduceToPrecision(std::string &input, int precision);

// Output streaming
DllExport
std::ostream &operator <<(std::ostream &out, const APFixBase &x);

// Input streaming
DllExport
std::istream &operator >> (std::istream &os, APFixBase &x);

DllExport
void print(const APFixBase &x);

// Operators mixing Integers with APFixBase
#define AF_BIN_OP_WITH_INT(BIN_OP, C_TYPE, _AP_W2,_AP_S2)                       \
   DllExport APFixBase operator BIN_OP (const APFixBase& op, C_TYPE i_op);                \
   DllExport APFixBase operator BIN_OP (C_TYPE i_op, const APFixBase& op);

#define AF_REL_OP_WITH_INT(REL_OP, C_TYPE, _AP_W2,_AP_S2)                       \
   DllExport bool operator REL_OP (const APFixBase& op, C_TYPE i_op);                     \
   DllExport bool operator REL_OP (C_TYPE i_op, const APFixBase& op);

#define AF_ASSIGN_OP_WITH_INT(ASSIGN_OP, C_TYPE, _AP_W2, _AP_S2)                \
   DllExport APFixBase& operator ASSIGN_OP ( APFixBase& op, C_TYPE i_op);

#define AF_ASSIGN_OP_WITH_INT_SF(ASSIGN_OP, C_TYPE, _AP_W2, _AP_S2)             \
   DllExport APFixBase& operator ASSIGN_OP ( APFixBase& op, C_TYPE i_op);

#define AF_OPS_WITH_INT(C_TYPE, WI, SI)                                         \
   AF_BIN_OP_WITH_INT(+, C_TYPE, WI, SI)                                        \
   AF_BIN_OP_WITH_INT(-, C_TYPE, WI, SI)                                        \
   AF_BIN_OP_WITH_INT(*, C_TYPE, WI, SI)                                        \
   AF_BIN_OP_WITH_INT(/, C_TYPE, WI, SI)                                        \
   AF_BIN_OP_WITH_INT(&, C_TYPE, WI, SI)                                        \
   AF_BIN_OP_WITH_INT(|, C_TYPE, WI, SI)                                        \
   AF_BIN_OP_WITH_INT(^, C_TYPE, WI, SI)                                        \
                                                                                \
   AF_REL_OP_WITH_INT(==, C_TYPE, WI, SI)                                       \
   AF_REL_OP_WITH_INT(!=, C_TYPE, WI, SI)                                       \
   AF_REL_OP_WITH_INT(>, C_TYPE, WI, SI)                                        \
   AF_REL_OP_WITH_INT(>=, C_TYPE, WI, SI)                                       \
   AF_REL_OP_WITH_INT(<, C_TYPE, WI, SI)                                        \
   AF_REL_OP_WITH_INT(<=, C_TYPE, WI, SI)                                       \
                                                                                \
   AF_ASSIGN_OP_WITH_INT(+=, C_TYPE, WI, SI)                                    \
   AF_ASSIGN_OP_WITH_INT(-=, C_TYPE, WI, SI)                                    \
   AF_ASSIGN_OP_WITH_INT(*=, C_TYPE, WI, SI)                                    \
   AF_ASSIGN_OP_WITH_INT(/=, C_TYPE, WI, SI)                                    \
   AF_ASSIGN_OP_WITH_INT_SF(>>=, C_TYPE, WI, SI)                                \
   AF_ASSIGN_OP_WITH_INT_SF(<<=, C_TYPE, WI, SI)                                \
   AF_ASSIGN_OP_WITH_INT(&=, C_TYPE, WI, SI)                                    \
   AF_ASSIGN_OP_WITH_INT(|=, C_TYPE, WI, SI)                                    \
   AF_ASSIGN_OP_WITH_INT(^=, C_TYPE, WI, SI)

AF_OPS_WITH_INT(bool, 1, false)
AF_OPS_WITH_INT(char, 8, true)
AF_OPS_WITH_INT(signed char, 8, true)
AF_OPS_WITH_INT(unsigned char, 8, false)
AF_OPS_WITH_INT(short, 16, true)
AF_OPS_WITH_INT(unsigned short, 16, false)
AF_OPS_WITH_INT(int, 32, true)
AF_OPS_WITH_INT(unsigned int, 32, false)
AF_OPS_WITH_INT(long, 64, true)
AF_OPS_WITH_INT(unsigned long, 64, false)
AF_OPS_WITH_INT(ap_slong, 64, true)
AF_OPS_WITH_INT(ap_ulong, 64, false)

#undef AF_BIN_OP_WITH_INT
#undef AF_REL_OP_WITH_INT
#undef AF_ASSIGN_OP_WITH_INT
#undef AF_ASSIGN_OP_WITH_INT_SF
#undef AF_OPS_WITH_INT

// Operators mixing APBase with APFixBase
#define AF_BIN_OP_WITH_AP_INT(BIN_OP)                                           \
   DllExport APFixBase operator BIN_OP ( const APBase& i_op, const APFixBase& op);        \
   DllExport APFixBase operator BIN_OP ( const APFixBase& op, const APBase& i_op);

#define AF_REL_OP_WITH_AP_INT(REL_OP)                                           \
   DllExport bool operator REL_OP ( const APFixBase& op, const APBase& i_op);             \
   DllExport bool operator REL_OP ( const APBase& i_op, const APFixBase& op);

#define AF_ASSIGN_OP_WITH_AP_INT(ASSIGN_OP)                                     \
   DllExport APFixBase& operator ASSIGN_OP ( APFixBase& op, const APBase& i_op);          \
   DllExport APBase& operator ASSIGN_OP ( APBase& i_op, const APFixBase& op);

AF_BIN_OP_WITH_AP_INT(+)
AF_BIN_OP_WITH_AP_INT(-)
AF_BIN_OP_WITH_AP_INT(*)
AF_BIN_OP_WITH_AP_INT(/)
AF_BIN_OP_WITH_AP_INT(&)
AF_BIN_OP_WITH_AP_INT(|)
AF_BIN_OP_WITH_AP_INT(^)

AF_REL_OP_WITH_AP_INT(==)
AF_REL_OP_WITH_AP_INT(!=)
AF_REL_OP_WITH_AP_INT(>)
AF_REL_OP_WITH_AP_INT(>=)
AF_REL_OP_WITH_AP_INT(<)
AF_REL_OP_WITH_AP_INT(<=)

AF_ASSIGN_OP_WITH_AP_INT(+=)
AF_ASSIGN_OP_WITH_AP_INT(-=)
AF_ASSIGN_OP_WITH_AP_INT(*=)
AF_ASSIGN_OP_WITH_AP_INT(/=)
AF_ASSIGN_OP_WITH_AP_INT(&=)
AF_ASSIGN_OP_WITH_AP_INT(|=)
AF_ASSIGN_OP_WITH_AP_INT(^=)

#undef AF_BIN_OP_WITH_AP_INT
#undef AF_REL_OP_WITH_AP_INT
#undef AF_ASSIGN_OP_WITH_AP_INT

// Operators mixing APFixRange and APFixBit with C data types
#define AF_REF_REL_OP_MIX_INT(REL_OP, C_TYPE, _AP_W2, _AP_S2)                   \
   DllExport bool operator REL_OP ( const APFixRange &op, C_TYPE op2);                    \
   DllExport bool operator REL_OP ( C_TYPE op2, const APFixRange &op);                    \
   DllExport bool operator REL_OP ( const APFixBit &op, C_TYPE op2);                      \
   DllExport bool operator REL_OP ( C_TYPE op2, const APFixBit &op);

#define AF_REF_REL_MIX_INT(C_TYPE, _AP_WI, _AP_SI)                              \
   AF_REF_REL_OP_MIX_INT(>, C_TYPE, _AP_WI, _AP_SI)                             \
   AF_REF_REL_OP_MIX_INT(<, C_TYPE, _AP_WI, _AP_SI)                             \
   AF_REF_REL_OP_MIX_INT(>=, C_TYPE, _AP_WI, _AP_SI)                            \
   AF_REF_REL_OP_MIX_INT(<=, C_TYPE, _AP_WI, _AP_SI)                            \
   AF_REF_REL_OP_MIX_INT(==, C_TYPE, _AP_WI, _AP_SI)                            \
   AF_REF_REL_OP_MIX_INT(!=, C_TYPE, _AP_WI, _AP_SI)

AF_REF_REL_MIX_INT(bool, 1, false)
AF_REF_REL_MIX_INT(char, 8, true)
AF_REF_REL_MIX_INT(signed char, 8, true)
AF_REF_REL_MIX_INT(unsigned char, 8, false)
AF_REF_REL_MIX_INT(short, 16, true)
AF_REF_REL_MIX_INT(unsigned short, 16, false)
AF_REF_REL_MIX_INT(int, 32, true)
AF_REF_REL_MIX_INT(unsigned int, 32, false)
AF_REF_REL_MIX_INT(long, 64, true)
AF_REF_REL_MIX_INT(unsigned long, 64, false)
AF_REF_REL_MIX_INT(ap_slong, 64, true)
AF_REF_REL_MIX_INT(ap_ulong, 64, false)

#undef AF_REF_REL_MIX_INT
#undef AF_REF_REL_OP_MIX_INT

// Operators mixing APFixRange and APFixBit with APBase
#define AF_REF_REL_OP_AP_INT(REL_OP)                                            \
   DllExport bool operator REL_OP ( const APFixRange &op, const APBase &op2);             \
   DllExport bool operator REL_OP ( const APBase &op2, const APFixRange &op);             \
   DllExport bool operator REL_OP ( const APFixBit &op, const APBase &op2);               \
   DllExport bool operator REL_OP ( const APBase &op2, const APFixBit &op);

AF_REF_REL_OP_AP_INT(>)
AF_REF_REL_OP_AP_INT(<)
AF_REF_REL_OP_AP_INT(>=)
AF_REF_REL_OP_AP_INT(<=)
AF_REF_REL_OP_AP_INT(==)
AF_REF_REL_OP_AP_INT(!=)

#undef AF_REF_REL_OP_AP_INT

// Operators mixing double and APFixBase
#define AF_REL_OP_AP_DOUBLE(REL_OP)                                             \
  DllExport bool operator REL_OP (double i_op, const APFixBase& op);                      \

AF_REL_OP_AP_DOUBLE(>)
AF_REL_OP_AP_DOUBLE(<)
AF_REL_OP_AP_DOUBLE(>=)
AF_REL_OP_AP_DOUBLE(<=)
AF_REL_OP_AP_DOUBLE(==)
AF_REL_OP_AP_DOUBLE(!=)

#undef AF_REL_OP_AP_DOUBLE

DllExport void add(APFixBase &out,const APFixBase &in1,const APFixBase &in2);
DllExport void sub(APFixBase &out,const APFixBase &in1,const APFixBase &in2);
DllExport void mult(APFixBase &out,const APFixBase &in1,const APFixBase &in2);

} //namespace hls


#endif // ifndef HLS_APFIX_BASE_EXT_H_
