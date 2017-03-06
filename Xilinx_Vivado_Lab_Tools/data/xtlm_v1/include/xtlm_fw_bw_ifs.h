
#ifndef XTLM_V1_IFS_H
#define XTLM_V1_IFS_H
#ifndef SYSTEMC_H
#include <systemc.h>
#endif
namespace xtlm_v1{
  template<typename TYPES = xtlm_protocol_types>
   class xtlm_fw_transport_if:public virtual sc_core::sc_interface{
  public:
    virtual void b_transport(	int socket_id,
        typename TYPES::tlm_payload_type & trans,
        sc_core::sc_time& t) = 0;
    virtual unsigned int transport_dbg ( 	int socket_id,
        typename TYPES::tlm_payload_type & trans) = 0;
    virtual bool get_direct_mem_ptr( int socket_id,
        typename TYPES::tlm_payload_type & trans,
        tlm::tlm_dmi& dmi_data ) = 0;
    virtual tlm::tlm_sync_enum
      nb_transport_fw(int socket_id,
          typename TYPES::tlm_payload_type & trans,
          typename TYPES::tlm_phase_type & phase,
          sc_core::sc_time & t) = 0;
  protected:
  private:
  };
  template<typename TYPES = xtlm_protocol_types>
class xtlm_bw_transport_if:public virtual sc_core::sc_interface{
  public:
    virtual void
      invalidate_direct_mem_ptr(int socket_id,
          sc_dt::uint64 start_range,
          sc_dt::uint64 end_range) = 0;

    virtual tlm::tlm_sync_enum
      nb_transport_bw(int socket_id,
        typename TYPES::tlm_payload_type & trans,
          typename TYPES::tlm_phase_type & phase,
          sc_core::sc_time & t) = 0;
  private:
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
