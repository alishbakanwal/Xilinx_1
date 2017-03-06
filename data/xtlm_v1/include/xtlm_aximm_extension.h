#ifndef XAXIMM_TLM_EXTENSION_H
#define XAXIMM_TLM_EXTENSION_H
#include <list>

namespace xtlm_v1{
#define XAXIMM_FIXED_BURST 0
#define XAXIMM_INCR_BURST  1
#define XAXIMM_WRAP_BURST  2
  class xtlm_aximm_extension:
    public tlm::tlm_extension<xtlm_aximm_extension>{
    public:
      xtlm_aximm_extension():tlm::tlm_extension<xtlm_aximm_extension>(){
      trans_id = 0;
      burst_type = 0;
      awuser.clear();
      wuser.clear();
      buser.clear();
      aruser.clear();
      acache = 0;
      aprot = 0;
      aqos = 0;
      aregion = 0;
      alock = 0;
      burst_size = 0;
      burst_length = 0;
      }
      virtual tlm::tlm_extension_base * clone() const{
        xtlm_aximm_extension* cl = new xtlm_aximm_extension();
        cl->copy_from(*this);
        return (cl);
      }
      virtual void copy_from(tlm::tlm_extension_base const & ext){
        sc_assert(ID == static_cast<xtlm_aximm_extension const &>(ext).ID);
        operator =(static_cast<xtlm_aximm_extension const &>(ext));

        xtlm_aximm_extension const& xaximm_ext = (static_cast<xtlm_aximm_extension const &>(ext));
        awuser = xaximm_ext.awuser;
        wuser  = xaximm_ext.wuser;
        buser  = xaximm_ext.buser;
        aruser = xaximm_ext.aruser;
        acache= xaximm_ext.acache;
        aprot = xaximm_ext.aprot;
        aqos  = xaximm_ext.aqos;
        aregion=xaximm_ext.aregion;
        ruser  = xaximm_ext.ruser;
        trans_id = xaximm_ext.trans_id;
        burst_type = xaximm_ext.burst_type;
        burst_length = xaximm_ext.burst_length;
        burst_size = xaximm_ext.burst_size;
        alock = xaximm_ext.alock;
      }
/*
      std::list<xsc::xsc_bv> awuser;
      std::list<xsc::xsc_bv> wuser;
      std::list<xsc::xsc_bv> ruser;
      std::list<xsc::xsc_bv> buser;
      std::list<xsc::xsc_bv> aruser;
*/
      std::list<hls::APBase> awuser;
      std::list<hls::APBase> wuser;
      std::list<hls::APBase> ruser;
      std::list<hls::APBase> buser;
      std::list<hls::APBase> aruser;

      unsigned int acache;
      unsigned int aprot;
      unsigned int aqos;
      unsigned int aregion;
      unsigned int alock;

      unsigned int trans_id;
      unsigned int burst_type;

      //burst_length and burst_size are set at the time
      //of receiving transaction. payload streaming_width 
      //and data_length are set when data is filled.

      //burst_length --> no of beats in transaction
      //data_length --> no of bytes in transaction
      unsigned int burst_length;
      //burst_size --> size specified in raddr or waddr phase
      //streaming_width --> width of the port
      unsigned int burst_size;
    protected:
    private:
    };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
