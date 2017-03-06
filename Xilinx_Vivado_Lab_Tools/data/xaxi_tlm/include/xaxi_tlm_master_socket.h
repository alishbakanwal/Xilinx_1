#ifndef XAXI_TLM_MASTER_SOCKET_H
#define XAXI_TLM_MASTER_SOCKET_H
namespace xaxi_tlm{
  class xaxi_tlm_master_socket_imp;
  class xaxi_tlm_master_socket
  {
  public:
    std::string name();
        
    xaxi_tlm_master_socket(	std::string master_socket_name_p, 
        int width_p,
        int socket_id = 0);

    ~xaxi_tlm_master_socket();
    
    virtual const char * kind() const;

    sc_core::sc_object*  master_socket_instance();  
   
    void b_transport(int socket_id,
        xaxi_tlm_transaction & trans,
        sc_core::sc_time & t);

    void b_transport(xaxi_tlm_transaction & trans, sc_core::sc_time & time){
      b_transport(0,trans,time);
    }

    unsigned int transport_dbg(int socket_id,
        xaxi_tlm_transaction & trans);

    unsigned int transport_dbg(xaxi_tlm_transaction & trans){
      return transport_dbg(0, trans);
    }

    bool get_direct_mem_ptr(int, xaxi_tlm_transaction &trans, tlm::tlm_dmi &dmi_data);

    bool get_direct_mem_ptr(xaxi_tlm_transaction & trans, tlm::tlm_dmi & tlmdmi){
      return get_direct_mem_ptr(0, trans,tlmdmi);
    }

    tlm::tlm_sync_enum
      nb_transport_fw(int socket_id,
          xaxi_tlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t);

    tlm::tlm_sync_enum
      nb_transport_fw(
          xaxi_tlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t){
        return nb_transport_fw(0,trans,phase,t);
      }

    void bind(xaxi_tlm_bw_transport_if &iface);

    void operator() (xaxi_tlm_bw_transport_if &iface){
      bind(iface);
    }

    void bind(xaxi_tlm::xaxi_tlm_slave_socket& slave_socket);
  private:
    /***Changing templated instance is not allowed since there is lifetime dependemcy***/
    sc_core::sc_object* get_master_socket_instance(std::string& socket_name,int width,int socket_id);

    xaxi_tlm_master_socket_imp* p_imp;
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
