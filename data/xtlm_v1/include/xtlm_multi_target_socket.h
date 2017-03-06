#ifndef XTLM_V1_MULTI_TARGET_SOCKET_H
#define XTLM_V1_MULTI_TARGET_SOCKET_H

namespace xtlm_v1{
  //Forward declaration
  //class xtlm_initiator_socket;
  class xtlm_multi_target_socket_imp;
  
  class xtlm_multi_target_socket
  {
  private:
    xtlm_multi_target_socket_imp* p_imp;
    /***Changing templated instance is not allowed since there is lifetime dependemcy***/
    sc_core::sc_object* get_target_socket_instance(std::string& socket_name,int width);
  public:
    std::string name();
       xtlm_multi_target_socket(std::string target_socket_name_p, int width_p);

       ~xtlm_multi_target_socket();
    const char * kind() const;

    sc_core::sc_object*  target_socket_instance();
  
    void bind(xtlm_v1::xtlm_fw_transport_if<xtlm_protocol_types> & iface) ;
    void operator() (xtlm_v1::xtlm_fw_transport_if<xtlm_protocol_types> &iface){bind(iface);}

    void bind(xtlm_v1::xtlm_multi_target_socket& multi_target_sock);
    void operator()(xtlm_v1::xtlm_multi_target_socket& multi_target_sock){bind(multi_target_sock);}

    tlm::tlm_bw_transport_if<xtlm_protocol_types>* operator[](int index);
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
