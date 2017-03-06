#ifndef XAXI_TLM_SLAVE_BASE_H
#define XAXI_TLM_SLAVE_BASE_H
namespace xaxi_tlm{
  class xaxi_tlm_slave_base:public virtual xaxi_tlm_fw_transport_if{
  public:
    explicit xaxi_tlm_slave_base(const std::string &name)
      :m_name(name){
      }
    std::string get_name(){return m_name;};

    virtual void b_transport(int,
        xaxi_tlm_transaction &,
        sc_core::sc_time &){
      //Translate in user layer calls
      return;
    }
    virtual unsigned int transport_dbg(int, xaxi_tlm_transaction &){
      //Translate in user layer calls
      return 0;
    }
    virtual bool get_direct_mem_ptr(int,
        xaxi_tlm_transaction &,
        tlm::tlm_dmi &){
      //Translate in user layer calls
      return false;
    }
    virtual tlm::tlm_sync_enum
      nb_transport_fw(int socket_id,
          xaxi_tlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t){
        //Translate in user layer calls
        return tlm::TLM_ACCEPTED;
      }
  protected:

  private:
    std::string m_name;
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
