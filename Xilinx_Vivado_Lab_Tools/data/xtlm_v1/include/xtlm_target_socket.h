#ifndef XTLM_V1_SLAVE_SOCKET_H
#define XTLM_V1_SLAVE_SOCKET_H
namespace xtlm_v1{

  //Forward declaration
  class xtlm_initiator_socket;
  class xtlm_simple_initiator_socket_tagged;
  class xtlm_simple_tagged_socket_tagged;
  class xtlm_target_socket_imp;
  
  class xtlm_target_socket
  {
  public:
    std::string name();
       xtlm_target_socket(std::string target_socket_name_p, int width_p);

       ~xtlm_target_socket();
    const char * kind() const;

    sc_core::sc_object*  target_socket_instance();
  
   
    void invalidate_direct_mem_ptr(sc_dt::uint64 start_range,
        sc_dt::uint64 end_range);

    tlm::tlm_sync_enum
      nb_transport_bw(xtlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t);

    void bind(tlm::tlm_fw_transport_if<xtlm_protocol_types> & iface) ;
    void operator() (tlm::tlm_fw_transport_if<xtlm_protocol_types> &iface){bind(iface);}

    void bind(xtlm_v1::xtlm_initiator_socket& initiator_socket);
    void operator()(xtlm_v1::xtlm_initiator_socket& initiator_socket){bind(initiator_socket);}

    void bind(xtlm_v1::xtlm_target_socket& target_socket_);
    void operator()(xtlm_v1::xtlm_target_socket& target_socket_){bind(target_socket_);};
    
    void bind(xtlm_v1::xtlm_simple_initiator_socket_tagged& xinit_socket);
    void operator()(xtlm_v1::xtlm_simple_initiator_socket_tagged& xinit_socket){bind(xinit_socket);};
    
    void bind(xtlm_v1::xtlm_simple_target_socket_tagged& xtarget_socket);
    void operator()(xtlm_v1::xtlm_simple_target_socket_tagged& xtarget_socket){bind(xtarget_socket);};
  private:
    xtlm_target_socket_imp* p_imp;
    sc_core::sc_object* get_target_socket_instance(std::string& socket_name,int width);
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
