#ifndef XAXI_TLM_SIMPLE_INITIATOR_SOCKET_TAGGED_H
#define XAXI_TLM_SIMPLE_INITIATOR_SOCKET_TAGGED_H
namespace xtlm_v1{
  class xtlm_simple_initiator_socket_tagged_imp;
  class xtlm_simple_initiator_socket_tagged
  {
  public:
    std::string name();
        
    xtlm_simple_initiator_socket_tagged(	std::string master_socket_name_p, 
        int width_p,
        int socket_id = 0);

    ~xtlm_simple_initiator_socket_tagged();
    
    virtual const char * kind() const;

    sc_core::sc_object*  master_socket_instance();  
   
    void b_transport(int socket_id,
        xtlm_transaction & trans,
        sc_core::sc_time & t);

    void b_transport(xtlm_transaction & trans, sc_core::sc_time & time){
      b_transport(0,trans,time);
    }

    unsigned int transport_dbg(int socket_id,
        xtlm_transaction & trans);

    unsigned int transport_dbg(xtlm_transaction & trans){
      return transport_dbg(0, trans);
    }

    bool get_direct_mem_ptr(int, xtlm_transaction &trans, tlm::tlm_dmi &dmi_data);

    bool get_direct_mem_ptr(xtlm_transaction & trans, tlm::tlm_dmi & tlmdmi){
      return get_direct_mem_ptr(0, trans,tlmdmi);
    }

    tlm::tlm_sync_enum
      nb_transport_fw(int socket_id,
          xtlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t);

    tlm::tlm_sync_enum
      nb_transport_fw(
          xtlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t){
        return nb_transport_fw(0,trans,phase,t);
      }

    void bind(xtlm_bw_transport_if<> &iface);

    void operator() (xtlm_bw_transport_if<> &iface){
      bind(iface);
    }

    void bind(xtlm_v1::xtlm_simple_target_socket_tagged& slave_socket);
    void bind(xtlm_v1::xtlm_initiator_socket& init_socket);
    void bind(xtlm_v1::xtlm_target_socket& targ_socket);
    void bind(xtlm_v1::xtlm_multi_target_socket& multi_targ_socket);
  private:
    /***Changing templated instance is not allowed since there is lifetime dependemcy***/
    sc_core::sc_object* get_master_socket_instance(std::string& socket_name,int width,int socket_id);

    xtlm_simple_initiator_socket_tagged_imp* p_imp;
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
