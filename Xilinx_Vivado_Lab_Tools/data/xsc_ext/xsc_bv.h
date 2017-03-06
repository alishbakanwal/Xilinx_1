#ifndef XSC_BV_H
#define XSC_BV_H
//This may require legal clearance
namespace xsc
{

class xsc_bv : public sc_bv_base
{
public:

    // constructors

    explicit xsc_bv(int W)
	:sc_bv_base( W )
	{}

    explicit xsc_bv(int W, bool init_value )
	: sc_bv_base( init_value, W )
	{}

	~xsc_bv(){
	}

    explicit xsc_bv(int W, char init_value )
	: sc_bv_base( (init_value != '0'), W )
	{}

    xsc_bv(int W, const char* a )
	: sc_bv_base( W )
	{ sc_bv_base::operator = ( a ); }

    xsc_bv(int W, const bool* a )
	: sc_bv_base( W )
	{ sc_bv_base::operator = ( a ); }

    xsc_bv(int W, const sc_logic* a )
	: sc_bv_base( W )
	{ sc_bv_base::operator = ( a ); }

    xsc_bv(int W, const sc_unsigned& a )
	: sc_bv_base( W )
	{ sc_bv_base::operator = ( a ); }

    xsc_bv(int W, const sc_signed& a )
	: sc_bv_base( W )
	{ sc_bv_base::operator = ( a ); }

    xsc_bv(int W, const sc_uint_base& a )
	: sc_bv_base( W )
	{ sc_bv_base::operator = ( a ); }

    xsc_bv(int W, const sc_int_base& a )
	: sc_bv_base( W )
	{ sc_bv_base::operator = ( a ); }

    xsc_bv(int W, unsigned long a )
	: sc_bv_base( W )
	{ sc_bv_base::operator = ( a ); }

    xsc_bv(int W, long a )
	: sc_bv_base( W )
	{ sc_bv_base::operator = ( a ); }

    xsc_bv(int W, unsigned int a )
	: sc_bv_base( W )
	{ sc_bv_base::operator = ( a ); }

    xsc_bv(int W, int a )
	: sc_bv_base( W )
	{ sc_bv_base::operator = ( a ); }

    xsc_bv(int W, uint64 a )
	: sc_bv_base( W )
	{ sc_bv_base::operator = ( a ); }

    xsc_bv(int W, int64 a )
	: sc_bv_base( W )
	{ sc_bv_base::operator = ( a ); }

    template <class X>
    xsc_bv(int W, const sc_proxy<X>& a )
	: sc_bv_base( W )
	{ sc_bv_base::operator = ( a ); }

    xsc_bv( const xsc_bv& a )
	: sc_bv_base( a )
	{}


    // assignment operators

    template <class X>
    xsc_bv& operator = ( const sc_proxy<X>& a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( const xsc_bv& a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( const sc_bv_base& a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( const char* a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( const bool* a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( const sc_logic* a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( const sc_unsigned& a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( const sc_signed& a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( const sc_uint_base& a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( const sc_int_base& a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( unsigned long a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( long a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( unsigned int a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( int a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( uint64 a )
	{ sc_bv_base::operator = ( a ); return *this; }

    xsc_bv& operator = ( int64 a )
	{ sc_bv_base::operator = ( a ); return *this; }
private:
    xsc_bv()
	:sc_bv_base( 1 )
	{}
};

} // namespace sc_dt


#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
