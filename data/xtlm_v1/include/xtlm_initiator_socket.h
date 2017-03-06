#ifndef XTLM_INITIATOR_SOCKET_H
#define XTLM_INITIATOR_SOCKET_H
namespace xtlm_v1{
  class xtlm_target_socket;
  class xtlm_simple_target_socket_tagged;
  class xtlm_multi_target_socket;
  class xtlm_initiator_socket_imp;
  class xtlm_initiator_socket
  {
  public:
    std::string name();

    xtlm_initiator_socket(	std::string initiator_socket_name_p, 
        int width_p);

    ~xtlm_initiator_socket();

    virtual const char * kind() const;

    sc_core::sc_object*  initiator_socket_instance();  

    void b_transport(xtlm_transaction & trans,
        sc_core::sc_time & t);

    unsigned int transport_dbg(xtlm_transaction & trans);

    bool get_direct_mem_ptr(xtlm_transaction &trans, tlm::tlm_dmi &dmi_data);


    tlm::tlm_sync_enum
      nb_transport_fw(xtlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t);

    void bind(tlm::tlm_bw_transport_if<xtlm_protocol_types> &iface);
    void operator() (tlm::tlm_bw_transport_if<xtlm_protocol_types> &iface){
      bind(iface);
    }

    void bind(xtlm_v1::xtlm_target_socket& target_socket);
    void operator()(xtlm_v1::xtlm_target_socket& target_socket){bind(target_socket);};

    void bind(xtlm_v1::xtlm_initiator_socket& initiator_socket_);
    void operator()(xtlm_v1::xtlm_initiator_socket& initiator_socket_){bind(initiator_socket_);};

    void bind(xtlm_v1::xtlm_multi_target_socket& multi_targ_sock);
    void operator()(xtlm_v1::xtlm_multi_target_socket& multi_targ_sock){bind(multi_targ_sock);};

    void bind(xtlm_v1::xtlm_simple_target_socket_tagged& xsimple_targ_sock);
    void operator()(xtlm_v1::xtlm_simple_target_socket_tagged& xsimple_targ_sock){bind(xsimple_targ_sock);};
  private:
    xtlm_initiator_socket_imp* p_imp;
    /***Changing templated instance is not allowed since there is lifetime dependemcy***/
    sc_core::sc_object* get_initiator_socket_instance(std::string& socket_name,int width);
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
