#include <systemc.h>

#ifndef XAXI_TLM_IFS_H
#define XAXI_TLM_IFS_H
namespace xaxi_tlm{
  class xaxi_tlm_fw_transport_if:public virtual sc_core::sc_interface{
  public:
    virtual void b_transport(	int socket_id,
        xaxi_tlm_transaction & trans,
        sc_core::sc_time& t) = 0;
    virtual unsigned int transport_dbg ( 	int socket_id,
        xaxi_tlm_transaction & trans) = 0;
    virtual bool get_direct_mem_ptr( int socket_id,
        xaxi_tlm_transaction & trans,
        tlm::tlm_dmi& dmi_data ) = 0;
    virtual tlm::tlm_sync_enum
      nb_transport_fw(int socket_id,
          xaxi_tlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t) = 0;
  protected:
  private:
  };
  class xaxi_tlm_bw_transport_if:public virtual sc_core::sc_interface{
  public:
    virtual void
      invalidate_direct_mem_ptr(int socket_id,
          sc_dt::uint64 start_range,
          sc_dt::uint64 end_range) = 0;

    virtual tlm::tlm_sync_enum
      nb_transport_bw(int socket_id,
          xaxi_tlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t) = 0;
  private:
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
