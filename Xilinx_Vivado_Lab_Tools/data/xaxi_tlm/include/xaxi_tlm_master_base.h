#ifndef XAXI_TLM_MASTER_BASE_H
#define XAXI_TLM_MASTER_BASE_H
namespace xaxi_tlm{
  class xaxi_tlm_master_base:public xaxi_tlm_bw_transport_if{
  public:
    explicit xaxi_tlm_master_base(const std::string &name): m_name(name) {
    }
    std::string get_name() const {
      return (m_name);
    }
    virtual void invalidate_direct_mem_ptr(int, sc_dt::uint64, sc_dt::uint64){
    }
    tlm::tlm_sync_enum nb_transport_bw(	int socket_id,
        xaxi_tlm_transaction & trans,
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
