#ifndef XTLM_MULTI_INITIATOR_SOCKET_H
#define XTLM_MULTI_INITIATOR_SOCKET_H
namespace xtlm_v1{
    
    class xtlm_target_socket;
    class xtlm_multi_target_socket;
  class xtlm_multi_initiator_socket_imp;
  class xtlm_multi_initiator_socket
  {
  public:
    std::string name();
        
    xtlm_multi_initiator_socket(	std::string initiator_socket_name_p, 
        int width_p);

    ~xtlm_multi_initiator_socket();
    
    virtual const char * kind() const;

    sc_core::sc_object*  initiator_socket_instance();  
    tlm::tlm_fw_transport_if<xtlm_protocol_types>* operator[](int index);
    void bind(xtlm_v1::xtlm_bw_transport_if<xtlm_protocol_types> &iface);
    void operator() (xtlm_v1::xtlm_bw_transport_if<xtlm_protocol_types> &iface){
      bind(iface);
    }

    void bind(xtlm_v1::xtlm_target_socket& target_socket);
    void operator()(xtlm_v1::xtlm_target_socket& target_socket){bind(target_socket);}
    
    void bind(xtlm_v1::xtlm_multi_initiator_socket& multi_initiator_sock);
    void operator()(xtlm_v1::xtlm_multi_initiator_socket& multi_initiator_sock){ bind(multi_initiator_sock);}

    void bind(xtlm_v1::xtlm_multi_target_socket& multi_target_sock);
    void operator()(xtlm_v1::xtlm_multi_target_socket& multi_target_sock){ bind(multi_target_sock);}

  private:
    /***Changing templated instance is not allowed since there is lifetime dependemcy***/
    sc_core::sc_object* get_initiator_socket_instance(std::string& socket_name,int width);

    xtlm_multi_initiator_socket_imp* p_imp;
  };
}
#endif

