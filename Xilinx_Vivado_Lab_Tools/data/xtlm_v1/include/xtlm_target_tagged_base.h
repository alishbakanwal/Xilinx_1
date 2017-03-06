#ifndef XTLM_V1_TARGET_TAGGED_BASE_H
#define XTLM_V1_TARGET_TAGGED_BASE_H
namespace xtlm_v1{
  class xtlm_target_tagged_base : public virtual xtlm_v1::xtlm_fw_transport_if<> {
  public:
    explicit xtlm_target_tagged_base(const std::string &name)
      :m_name(name){
      }
    std::string get_name(){return m_name;};

    virtual void b_transport(int socket_id, xtlm_transaction &,
        sc_core::sc_time &){
      //Translate in user layer calls
      return;
    }
    virtual unsigned int transport_dbg(int socket_id, xtlm_transaction &){
      //Translate in user layer calls
      return 0;
    }
    virtual bool get_direct_mem_ptr(int sockte_id, xtlm_transaction &,
        tlm::tlm_dmi &){
      //Translate in user layer calls
      return false;
    }
    virtual tlm::tlm_sync_enum
      nb_transport_fw(int socket_id, xtlm_transaction & trans,
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
