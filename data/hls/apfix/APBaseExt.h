#ifndef HLS_AP_EXT_H
#define HLS_AP_EXT_H

#ifdef __linux__
#define DllExport
#else
#define DllExport  __declspec( dllexport ) 
#endif

#include <iostream>
#include"APBase.h"

namespace hls {

///Forward Declarations
class APBit;
class APRange;

class APFixBase;
class APFixRange;
class APFixBit;

// *****************************************************************************
// class APConcat
//
/// This is the APConcat class; it helps to concatenate two APBase value.  used
/// to Concatenate APBase and other objects Proxy class which allows
/// concatenation to be used as r-value(for reading)and l-value(for writing)
///
/// Object Concatenation.
/// TODO - We can use m_bv1 and m_bv2 as object reference to avoid data copy
// *****************************************************************************
class DllExport APConcat {
#ifdef RDIPF_win
#pragma warning( disable : 4521 4522 )
#endif

public:
   APBase m_bv1;
   APBase m_bv2;

   APConcat(const APConcat &ref);
   APConcat(const APBase &bv1, const APBase &bv2);

   APConcat &operator = (const APBase &val);
   APConcat &operator = (unsigned long long val);
   APConcat &operator = (const APConcat  &val);
   APConcat &operator = (const APBit &val);
   APConcat &operator = (const APRange &val);
   APConcat &operator = (const APFixRange &val);
   APConcat &operator = (const APFixBase &val);
   APConcat &operator = (const APFixBit &val);
   operator APBase () const;

   APConcat operator, (const APRange &a2);
   APConcat operator, (const APBase &a2);
   APConcat operator, (const APBit &a2);
   APConcat operator, (const APConcat &a2);
   APConcat operator, (const APFixRange &a2);
   APConcat operator, (const APFixBit &a2);
   APBase operator & (const APBase &a2);
   APBase operator | (const APBase &a2);
   APBase operator ^ (const APBase &a2);

   const APBase get() const;
   APBase get();
   void set(const APBase &val);
   int length() const;
   std::string to_string(uint8_t radix=2) const;
};


// *****************************************************************************
// class APRange
//
/// This is the APRange class; it class helps to part select the APBase value
/// used to slice APBase objects.  Proxy class, which allows part selection to
/// be used as rvalue(for reading) and lvalue(for writing)
///
/// Object Range for slicing.
/// TODO - We can use m_bv as object reference to avoid data copy
// *****************************************************************************
class DllExport APRange {
#ifdef RDIPF_win
#pragma warning( disable : 4521 4522 )
#endif

public:
   APBase &m_bv;
   int m_lIndex;
   int m_hIndex;

   APRange(const APRange &ref);
   APRange(APBase &bv, int h, int l);

   operator APBase () const;
   APRange &operator = (const APBase &val);
   APRange &operator = (unsigned long long val);
   APRange &operator = (const APConcat &val);
   APRange &operator = (const APRange &val);
   APRange &operator = (const APFixRange &val);
   APRange &operator = (const APFixBase &val);
   APRange &operator = (const APFixBit &val);
   APRange &operator = (const APBit &val);
   APConcat operator, (const APRange &a2) ;
   APConcat operator, (const APBase &a2);
   APConcat operator, (const APBit &a2);
   APConcat operator, (const APConcat &a2);
   APConcat operator, (const APFixRange &a2);
   APConcat operator, (const APFixBit &a2);
   bool operator == (const APRange &op2);
   bool operator != (const APRange &op2);
   bool operator > (const APRange &op2);
   bool operator >= (const APRange &op2);
   bool operator < (const APRange &op2);
   bool operator <= (const APRange &op2);

   void set(const APBase &val);
   const APBase get() const;
   APBase get();

   int length() const;
   int to_int() const;
   unsigned int to_uint() const;
   long to_long() const;
   unsigned long to_ulong() const;
   signed long to_int64() const;
   uint64_t to_uint64() const;
   std::string to_string(uint8_t radix=2) const;

   bool and_reduce();
   bool or_reduce();
   bool xor_reduce();
};

// *****************************************************************************
// class APBit
//
/// This is the APBit class; it helps to bit select the APBase value.  used to
/// select a bit from APBase Proxy class, which allows bit selection to be used
/// as rvalue(for reading) and lvalue(for writing)
///
/// Object bit selection
/// TODO - We can use m_bv as object reference to avoid data copy
// *****************************************************************************
class DllExport APBit {
#ifdef RDIPF_win
#pragma warning( disable : 4521 4522 )
#endif

public:
   APBase &m_bv;
   int m_index;

   APBit(const APBit &ref);
   APBit(APBase &bv, int index=0);

   operator bool () const;
   APBit &operator = (unsigned long long val);
   APBit &operator = (const APBase &val);
   APBit &operator = (const APBit &val);
   APBit &operator = (const APRange  &val);
   APBit &operator = (const APFixRange &val);
   APBit &operator = (const APFixBit &val);
   APBit &operator = (const APConcat &val);
   APConcat operator, (const APBase &a2);
   APConcat operator, (const APRange &a2);
   APConcat operator, (const APBit &a2);
   APConcat operator, (const APConcat &a2);
   APConcat operator, (const APFixRange &a2);
   APConcat operator, (const APFixBit &a2);
   bool operator == (const APBit &op);
   bool operator != (const APBit &op);
   bool operator~ () const;

   bool to_bool() const;
   bool get() const;

   bool get();
   void set(const APBase &val);
   int length() const;
   std::string to_string() const;
};

// *****************************************************************************
// APBase Utilities for operator overloading
// *****************************************************************************

// Binary operation
// Implement arithmetic, logical and relational operation between C++
// native data types, APBase, APBit, APRange,
// APConcat, APFixRange and APFixBit
// All these operator are added to avoid ambiguous error messages

// *****************************************************************************
//
/// Example code snippet
/// char a[100];
/// char* ptr = a;
/// APBase n(3,0,3);
/// char* ptr2 = ptr + n*2;
// *****************************************************************************

// *****************************************************************************
/// Pointer Arithmetic
/// + and -
// *****************************************************************************
#define OP_BIN_MIX_PTR(PTR_TYPE, BIN_OP)                                        \
DllExport PTR_TYPE* operator BIN_OP (PTR_TYPE* i_op, const APBase &op);                   \
DllExport PTR_TYPE* operator BIN_OP (const APBase &op, PTR_TYPE* i_op);
OP_BIN_MIX_PTR(char, +)
OP_BIN_MIX_PTR(char, -)
OP_BIN_MIX_PTR(short int, +)
OP_BIN_MIX_PTR(short int, -)
OP_BIN_MIX_PTR(int, +)
OP_BIN_MIX_PTR(int, -)
OP_BIN_MIX_PTR(unsigned int, +)
OP_BIN_MIX_PTR(unsigned int, -)
OP_BIN_MIX_PTR(long, +)
OP_BIN_MIX_PTR(long, -)
OP_BIN_MIX_PTR(unsigned long, +)
OP_BIN_MIX_PTR(unsigned long, -)
OP_BIN_MIX_PTR(float, +)
OP_BIN_MIX_PTR(float, -)
OP_BIN_MIX_PTR(double, +)
OP_BIN_MIX_PTR(double, -)
#undef OP_BIN_MIX_PTR

// *****************************************************************************
///Floating point Arithmetic
// *****************************************************************************
#define OP_BIN_MIX_FLOAT(BIN_OP, C_TYPE)                                        \
   DllExport C_TYPE operator BIN_OP (C_TYPE i_op, const APBase &op);                      \
   DllExport C_TYPE operator BIN_OP (const APBase &op, C_TYPE i_op);

#define OPS_MIX_FLOAT(C_TYPE)                                                   \
   OP_BIN_MIX_FLOAT(*, C_TYPE)                                                  \
   OP_BIN_MIX_FLOAT(/, C_TYPE)                                                  \
   OP_BIN_MIX_FLOAT(+, C_TYPE)                                                  \
   OP_BIN_MIX_FLOAT(-, C_TYPE)

OPS_MIX_FLOAT(float)
OPS_MIX_FLOAT(double)
#undef OP_BIN_MIX_FLOAT
#undef OPS_MIX_FLOAT

// *****************************************************************************
/// Operators mixing Integers with APBase
/// for F_AP_W > 64, we will explicitly convert operand with native data type
/// into corresponding APBase
/// for F_AP_W <= 64, we will implicitly convert operand with APBase into
/// (unsigned) long long
// *****************************************************************************

#define OP_BIN_MIX_INT(BIN_OP, C_TYPE, _AP_WI, _AP_SI)                          \
   DllExport APBase operator BIN_OP ( C_TYPE i_op, const APBase &op);                     \
   DllExport APBase operator BIN_OP ( const APBase &op, C_TYPE i_op);

#define OP_REL_MIX_INT(REL_OP, C_TYPE, _AP_W2, _AP_S2)                          \
   DllExport bool operator REL_OP ( const APBase &op, C_TYPE op2);                        \
   DllExport bool operator REL_OP ( C_TYPE op2, const APBase &op);

#define OP_ASSIGN_MIX_INT(ASSIGN_OP, C_TYPE, _AP_W2, _AP_S2)                    \
   DllExport APBase& operator ASSIGN_OP ( APBase &op, C_TYPE op2);

#define OP_ASSIGN_RSHIFT_INT(ASSIGN_OP, C_TYPE)                                 \
   DllExport APBase& operator ASSIGN_OP ( APBase &op, C_TYPE op2);

#define OP_ASSIGN_LSHIFT_INT(ASSIGN_OP, C_TYPE)                                 \
   DllExport APBase& operator ASSIGN_OP ( APBase &op, C_TYPE op2);

#define OPS_MIX_INT(C_TYPE, WI, SI)                                             \
   OP_BIN_MIX_INT(*, C_TYPE, WI, SI)                                            \
   OP_BIN_MIX_INT(+, C_TYPE, WI, SI)                                            \
   OP_BIN_MIX_INT(-, C_TYPE, WI, SI)                                            \
   OP_BIN_MIX_INT(/, C_TYPE, WI, SI)                                            \
   OP_BIN_MIX_INT(%, C_TYPE, WI, SI)                                            \
   OP_BIN_MIX_INT(&, C_TYPE, WI, SI)                                            \
   OP_BIN_MIX_INT(|, C_TYPE, WI, SI)                                            \
   OP_BIN_MIX_INT(^, C_TYPE, WI, SI)                                            \
                                                                                \
   OP_REL_MIX_INT(==, C_TYPE, WI, SI)                                           \
   OP_REL_MIX_INT(!=, C_TYPE, WI, SI)                                           \
   OP_REL_MIX_INT(>, C_TYPE, WI, SI)                                            \
   OP_REL_MIX_INT(>=, C_TYPE, WI, SI)                                           \
   OP_REL_MIX_INT(<, C_TYPE, WI, SI)                                            \
   OP_REL_MIX_INT(<=, C_TYPE, WI, SI)                                           \
                                                                                \
   OP_ASSIGN_MIX_INT(+=, C_TYPE, WI, SI)                                        \
   OP_ASSIGN_MIX_INT(-=, C_TYPE, WI, SI)                                        \
   OP_ASSIGN_MIX_INT(*=, C_TYPE, WI, SI)                                        \
   OP_ASSIGN_MIX_INT(/=, C_TYPE, WI, SI)                                        \
   OP_ASSIGN_MIX_INT(%=, C_TYPE, WI, SI)                                        \
   OP_ASSIGN_MIX_INT(&=, C_TYPE, WI, SI)                                        \
   OP_ASSIGN_MIX_INT(|=, C_TYPE, WI, SI)                                        \
   OP_ASSIGN_MIX_INT(^=, C_TYPE, WI, SI)                                        \
   OP_ASSIGN_RSHIFT_INT(>>=, C_TYPE)                                            \
   OP_ASSIGN_LSHIFT_INT(<<=, C_TYPE)

OPS_MIX_INT(bool, 1, false)
OPS_MIX_INT(char, 8, true)
OPS_MIX_INT(signed char, 8, true)
OPS_MIX_INT(unsigned char, 8, false)
OPS_MIX_INT(short, 16, true)
OPS_MIX_INT(unsigned short, 16, false)
OPS_MIX_INT(int, 32, true)
OPS_MIX_INT(unsigned int, 32, false)
OPS_MIX_INT(long, 64, true)
OPS_MIX_INT(unsigned long, 64, false)
OPS_MIX_INT(ap_slong, 64, true)
OPS_MIX_INT(ap_ulong, 64, false)

#undef OP_BIN_MIX_INT
#undef OP_REL_MIX_INT
#undef OP_ASSIGN_MIX_INT
#undef OP_ASSIGN_RSHIFT_INT
#undef OP_ASSIGN_LSHIFT_INT
#undef OPS_MIX_INT

// *****************************************************************************
/// Operators mixing APRange and APBase
// *****************************************************************************
#define OP_BIN_MIX_RANGE(BIN_OP)                                                \
   DllExport APBase operator BIN_OP ( const APRange& op1, const APBase& op2);             \
   DllExport APBase operator BIN_OP ( const APBase& op1, const APRange& op2);

#define OP_REL_MIX_RANGE(REL_OP)                                                \
   DllExport bool operator REL_OP ( const APRange& op1, const APBase& op2);               \
   DllExport bool operator REL_OP ( const APBase& op1, const APRange& op2);

#define OP_ASSIGN_MIX_RANGE(ASSIGN_OP)                                          \
   DllExport APBase& operator ASSIGN_OP ( APBase& op1, const APRange& op2);               \
   DllExport APRange& operator ASSIGN_OP (APRange& op1, APBase& op2);

OP_ASSIGN_MIX_RANGE(+=)
OP_ASSIGN_MIX_RANGE(-=)
OP_ASSIGN_MIX_RANGE(*=)
OP_ASSIGN_MIX_RANGE(/=)
OP_ASSIGN_MIX_RANGE(%=)
OP_ASSIGN_MIX_RANGE(>>=)
OP_ASSIGN_MIX_RANGE(<<=)
OP_ASSIGN_MIX_RANGE(&=)
OP_ASSIGN_MIX_RANGE(|=)
OP_ASSIGN_MIX_RANGE(^=)

OP_REL_MIX_RANGE(==)
OP_REL_MIX_RANGE(!=)
OP_REL_MIX_RANGE(>)
OP_REL_MIX_RANGE(>=)
OP_REL_MIX_RANGE(<)
OP_REL_MIX_RANGE(<=)

OP_BIN_MIX_RANGE(+)
OP_BIN_MIX_RANGE(-)
OP_BIN_MIX_RANGE(*)
OP_BIN_MIX_RANGE(/)
OP_BIN_MIX_RANGE(%)
OP_BIN_MIX_RANGE(>>)
OP_BIN_MIX_RANGE(<<)
OP_BIN_MIX_RANGE(&)
OP_BIN_MIX_RANGE(|)
OP_BIN_MIX_RANGE(^)

#undef OP_BIN_MIX_RANGE
#undef OP_REL_MIX_RANGE
#undef OP_ASSIGN_MIX_RANGE

// *****************************************************************************
/// Operators mixing APBit and APBase
// *****************************************************************************
#define OP_BIN_MIX_BIT(BIN_OP)                                                  \
   DllExport APBase operator BIN_OP ( const APBit& op1, const APBase& op2);               \
   DllExport APBase operator BIN_OP ( const APBase& op1, const APBit& op2);

#define OP_REL_MIX_BIT(REL_OP)                                                  \
   DllExport bool operator REL_OP ( const APBit& op1, const APBase& op2);                 \
   DllExport bool operator REL_OP ( const APBase& op1, const APBit& op2);
#define OP_ASSIGN_MIX_BIT(ASSIGN_OP)                                            \
   DllExport APBase& operator ASSIGN_OP ( APBase& op1, APBit& op2);                       \
   DllExport APBit& operator ASSIGN_OP ( APBit& op1, APBase& op2);

OP_ASSIGN_MIX_BIT(+=)
OP_ASSIGN_MIX_BIT(-=)
OP_ASSIGN_MIX_BIT(*=)
OP_ASSIGN_MIX_BIT(/=)
OP_ASSIGN_MIX_BIT(%=)
OP_ASSIGN_MIX_BIT(>>=)
OP_ASSIGN_MIX_BIT(<<=)
OP_ASSIGN_MIX_BIT(&=)
OP_ASSIGN_MIX_BIT(|=)
OP_ASSIGN_MIX_BIT(^=)

OP_REL_MIX_BIT(==)
OP_REL_MIX_BIT(!=)
OP_REL_MIX_BIT(>)
OP_REL_MIX_BIT(>=)
OP_REL_MIX_BIT(<)
OP_REL_MIX_BIT(<=)

OP_BIN_MIX_BIT(+)
OP_BIN_MIX_BIT(-)
OP_BIN_MIX_BIT(*)
OP_BIN_MIX_BIT(/)
OP_BIN_MIX_BIT(%)
OP_BIN_MIX_BIT(>>)
OP_BIN_MIX_BIT(<<)
OP_BIN_MIX_BIT(&)
OP_BIN_MIX_BIT(|)
OP_BIN_MIX_BIT(^)

#undef OP_BIN_MIX_BIT
#undef OP_REL_MIX_BIT
#undef OP_ASSIGN_MIX_BIT

// *****************************************************************************
/// Macro REF_REL_MIX_INT
//
/// This is the REF_REL_MIX_INT macro which which declares relational operators
/// with operands of different types.
// *****************************************************************************
#define REF_REL_OP_MIX_INT(REL_OP, C_TYPE, _AP_W2, _AP_S2)                      \
   DllExport bool operator REL_OP ( const APRange &op, C_TYPE op2);                       \
   DllExport bool operator REL_OP ( C_TYPE op2, const APRange &op);                       \
   DllExport bool operator REL_OP ( const APBit &op, C_TYPE op2);                         \
   DllExport bool operator REL_OP ( C_TYPE op2, const APBit &op);                         \
   DllExport bool operator REL_OP ( const APConcat &op, C_TYPE op2);                      \
   DllExport bool operator REL_OP ( C_TYPE op2, const APConcat &op);

#define REF_REL_MIX_INT(C_TYPE, _AP_WI, _AP_SI)                                 \
   REF_REL_OP_MIX_INT(>, C_TYPE, _AP_WI, _AP_SI)                                \
   REF_REL_OP_MIX_INT(<, C_TYPE, _AP_WI, _AP_SI)                                \
   REF_REL_OP_MIX_INT(>=, C_TYPE, _AP_WI, _AP_SI)                               \
   REF_REL_OP_MIX_INT(<=, C_TYPE, _AP_WI, _AP_SI)                               \
   REF_REL_OP_MIX_INT(==, C_TYPE, _AP_WI, _AP_SI)                               \
   REF_REL_OP_MIX_INT(!=, C_TYPE, _AP_WI, _AP_SI)

REF_REL_MIX_INT(bool, 1, false)
REF_REL_MIX_INT(char, 8, true)
REF_REL_MIX_INT(signed char, 8, true)
REF_REL_MIX_INT(unsigned char, 8, false)
REF_REL_MIX_INT(short, 16, true)
REF_REL_MIX_INT(unsigned short, 16, false)
REF_REL_MIX_INT(int, 32, true)
REF_REL_MIX_INT(unsigned int, 32, false)
REF_REL_MIX_INT(long, 64, true)
REF_REL_MIX_INT(unsigned long, 64, false)
REF_REL_MIX_INT(ap_slong, 64, true)
REF_REL_MIX_INT(ap_ulong, 64, false)

#undef REF_REL_OP_MIX_INT
#undef REF_REL_MIX_INT

// *****************************************************************************
// Macro REF_BIN_MIX_INT
//
/// This is the REF_BIN_MIX_INT macro which declares arithmetic operators for
/// an operator of an integer type  and another operand of type APRange.
// *****************************************************************************
#define REF_BIN_OP_MIX_INT(BIN_OP, C_TYPE, _AP_W2, _AP_S2)                      \
   DllExport APBase operator BIN_OP ( const APRange &op, C_TYPE op2);                     \
   DllExport APBase operator BIN_OP ( C_TYPE op2, const APRange &op);

#define REF_BIN_MIX_INT(C_TYPE, _AP_WI, _AP_SI)                                 \
   REF_BIN_OP_MIX_INT(+, C_TYPE, _AP_WI, _AP_SI)                                \
   REF_BIN_OP_MIX_INT(-, C_TYPE, _AP_WI, _AP_SI)                                \
   REF_BIN_OP_MIX_INT(*, C_TYPE, _AP_WI, _AP_SI)                                \
   REF_BIN_OP_MIX_INT(/, C_TYPE, _AP_WI, _AP_SI)                                \
   REF_BIN_OP_MIX_INT(%, C_TYPE, _AP_WI, _AP_SI)                                \
   REF_BIN_OP_MIX_INT(>>, C_TYPE, _AP_WI, _AP_SI)                               \
   REF_BIN_OP_MIX_INT(<<, C_TYPE, _AP_WI, _AP_SI)                               \
   REF_BIN_OP_MIX_INT(&, C_TYPE, _AP_WI, _AP_SI)                                \
   REF_BIN_OP_MIX_INT(|, C_TYPE, _AP_WI, _AP_SI)                                \
   REF_BIN_OP_MIX_INT(^, C_TYPE, _AP_WI, _AP_SI)

REF_BIN_MIX_INT(bool, 1, false)
REF_BIN_MIX_INT(char, 8, true)
REF_BIN_MIX_INT(signed char, 8, true)
REF_BIN_MIX_INT(unsigned char, 8, false)
REF_BIN_MIX_INT(short, 16, true)
REF_BIN_MIX_INT(unsigned short, 16, false)
REF_BIN_MIX_INT(int, 32, true)
REF_BIN_MIX_INT(unsigned int, 32, false)
REF_BIN_MIX_INT(long, 64, true)
REF_BIN_MIX_INT(unsigned long, 64, false)
REF_BIN_MIX_INT(ap_slong, 64, true)
REF_BIN_MIX_INT(ap_ulong, 64, false)

#undef REF_BIN_OP_MIX_INT
#undef REF_BIN_MIX_INT

// *****************************************************************************
/// Arithmetic operators mixing APRange with APRange
// *****************************************************************************
#define REF_BIN_OP(BIN_OP)                                                      \
DllExport APBase operator BIN_OP (const APRange &lhs, const APRange &rhs);

REF_BIN_OP(+)
REF_BIN_OP(-)
REF_BIN_OP(*)
REF_BIN_OP(/)
REF_BIN_OP(%)
REF_BIN_OP(>>)
REF_BIN_OP(<<)
REF_BIN_OP(&)
REF_BIN_OP(|)
REF_BIN_OP(^)

#undef REF_BIN_OP

// *****************************************************************************
/// Macro CONCAT_OP_MIX_INT
//
/// This macro defines concatenation operators mixing integers with APBase,
/// APRange and APConcat.
// *****************************************************************************
#define CONCAT_OP_MIX_INT(C_TYPE, _AP_WI, _AP_SI)                               \
   DllExport APBase operator, (const APBase &op1, C_TYPE op2);                            \
   DllExport APBase operator, (C_TYPE op1, const APBase& op2);                            \
   DllExport APBase operator, (const APRange &op1, C_TYPE op2);                           \
   DllExport APBase operator, (C_TYPE op1, const APRange &op2);                           \
   DllExport APBase operator, (const APBit &op1, C_TYPE op2);                             \
   DllExport APBase operator, (C_TYPE op1, const APBit &op2);                             \
   DllExport APBase operator, (const APConcat &op1,C_TYPE op2);                           \
   DllExport APBase operator, (C_TYPE op1,const APConcat &op2);                           \
   DllExport APBase operator, (const APFixRange &op1,C_TYPE op2);                         \
   DllExport APBase operator, (C_TYPE op1, const APFixRange &op2);                        \
   DllExport APBase operator, (const APFixBit &op1, C_TYPE op2);                          \
   DllExport APBase operator, (C_TYPE op1, const APFixBit &op2);

CONCAT_OP_MIX_INT(bool, 1, false)
CONCAT_OP_MIX_INT(char, 8, true)
CONCAT_OP_MIX_INT(signed char, 8, true)
CONCAT_OP_MIX_INT(unsigned char, 8, false)
CONCAT_OP_MIX_INT(short, 16, true)
CONCAT_OP_MIX_INT(unsigned short, 16, false)
CONCAT_OP_MIX_INT(int, 32, true)
CONCAT_OP_MIX_INT(unsigned int, 32, false)
CONCAT_OP_MIX_INT(long, 64, true)
CONCAT_OP_MIX_INT(unsigned long, 64, false)
CONCAT_OP_MIX_INT(ap_slong, 64, true)
CONCAT_OP_MIX_INT(ap_ulong, 64, false)

#undef CONCAT_OP_MIX_INT

// *****************************************************************************
/// Relational operators mixing integers with APConcat
// *****************************************************************************
#define CONCAT_SHIFT_MIX_INT(C_TYPE, op)                                        \
   DllExport APBase operator op (const APConcat lhs, C_TYPE rhs);

CONCAT_SHIFT_MIX_INT(long, <<)
CONCAT_SHIFT_MIX_INT(unsigned long, <<)
CONCAT_SHIFT_MIX_INT(unsigned int, <<)
CONCAT_SHIFT_MIX_INT(ap_ulong, <<)
CONCAT_SHIFT_MIX_INT(ap_slong, <<)
CONCAT_SHIFT_MIX_INT(long, >>)
CONCAT_SHIFT_MIX_INT(unsigned long, >>)
CONCAT_SHIFT_MIX_INT(unsigned int, >>)
CONCAT_SHIFT_MIX_INT(ap_ulong, >>)
CONCAT_SHIFT_MIX_INT(ap_slong, >>)

#undef CONCAT_SHIFT_MIX_INT

// *****************************************************************************
/// Input/Output Stream operators overloading for APBase, APRange
/// and APConcat
// *****************************************************************************
DllExport std::ostream& operator<<(std::ostream &out, const APBase &op);
DllExport std::istream &operator >> (std::istream &in, APBase &op);
DllExport std::ostream &operator<<(std::ostream &out, const APRange &op);
DllExport std::istream &operator >> (std::istream &in, APRange &op);
DllExport void print(const APBase &op);

} //namespace hls
#endif ///HLS_AP_EXT_H
