#ifndef XTLM_V1_SLAVE_BASE_H
#define XTLM_V1_SLAVE_BASE_H
namespace xtlm_v1{
  class xtlm_target_base : public virtual tlm::tlm_fw_transport_if<xtlm_protocol_types> {
  public:
    explicit xtlm_target_base(const std::string &name)
      :m_name(name){
      }
    std::string get_name(){return m_name;};

    virtual void b_transport(xtlm_transaction &,
        sc_core::sc_time &){
      //Translate in user layer calls
      return;
    }
    virtual unsigned int transport_dbg(xtlm_transaction &){
      //Translate in user layer calls
      return 0;
    }
    virtual bool get_direct_mem_ptr(xtlm_transaction &,
        tlm::tlm_dmi &){
      //Translate in user layer calls
      return false;
    }
    virtual tlm::tlm_sync_enum
      nb_transport_fw(xtlm_transaction & trans,
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
