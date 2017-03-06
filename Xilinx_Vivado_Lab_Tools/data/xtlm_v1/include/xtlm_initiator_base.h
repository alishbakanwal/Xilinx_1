#ifndef XTLM_V1_MASTER_BASE_H
#define XTLM_V1_MASTER_BASE_H
#ifndef __TLM_HEADER__
#include "tlm.h"
#endif
namespace xtlm_v1{
  class xtlm_initiator_base : public virtual tlm::tlm_bw_transport_if<xtlm_v1::xtlm_protocol_types> {
  public:
    explicit xtlm_initiator_base(const std::string &name): m_name(name) {
    }
    std::string get_name() const {
      return (m_name);
    }
    virtual void invalidate_direct_mem_ptr(sc_dt::uint64, sc_dt::uint64){
    }
    tlm::tlm_sync_enum nb_transport_bw( xtlm_transaction & trans,
        tlm::tlm_phase & phase,
        sc_core::sc_time & t){
          return tlm::TLM_ACCEPTED;
    }
  protected:

  private:
    std::string m_name;
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
