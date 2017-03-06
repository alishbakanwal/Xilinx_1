#ifndef XTLM_V1_INITIATOR_TAGGED_BASE_H
#define XTLM_V1_INITIATOR_TAGGED_BASE_H
#ifndef __TLM_HEADER__
#include "tlm.h"
#endif
namespace xtlm_v1{
  class xtlm_initiator_tagged_base : public virtual xtlm_v1::xtlm_bw_transport_if<> {
  public:
    explicit xtlm_initiator_tagged_base(const std::string &name): m_name(name) {
    }
    std::string get_name() const {
      return (m_name);
    }
    virtual void invalidate_direct_mem_ptr(int socket_id, sc_dt::uint64, sc_dt::uint64){
    }
    tlm::tlm_sync_enum nb_transport_bw( int socket_id, xtlm_transaction & trans,
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
