#ifndef XAXI_TLM_SLAVE_SOCKET_H
#define XAXI_TLM_SLAVE_SOCKET_H

namespace xaxi_tlm{

  //Forward declaration
  class xaxi_tlm_master_socket;
  class xaxi_tlm_slave_socket_imp;
  
  class xaxi_tlm_slave_socket
  {
  private:
    xaxi_tlm_slave_socket_imp* p_imp;
    /***Changing templated instance is not allowed since there is lifetime dependemcy***/
    sc_core::sc_object* get_slave_socket_instance(std::string& socket_name,int width,int socket_id);
  public:
    std::string name();
       xaxi_tlm_slave_socket(std::string slave_socket_name_p, int width_p, int socket_id = 0);

       ~xaxi_tlm_slave_socket();
    const char * kind() const;

    sc_core::sc_object*  slave_socket_instance();
  
   
    void invalidate_direct_mem_ptr(int socket_id,
        sc_dt::uint64 start_range,
        sc_dt::uint64 end_range);

    void invalidate_direct_mem_ptr(sc_dt::uint64 start_range, sc_dt::uint64 end_range){
      invalidate_direct_mem_ptr(0, start_range, end_range);		
    }

    tlm::tlm_sync_enum
      nb_transport_bw(int socket_id,
          xaxi_tlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t);
    tlm::tlm_sync_enum
      nb_transport_bw(xaxi_tlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t){
        return (nb_transport_bw(0,trans,phase,t));
      }

    void bind(xaxi_tlm_fw_transport_if & iface) ;

    void operator() (xaxi_tlm_fw_transport_if &iface){bind(iface);}

    void bind(xaxi_tlm::xaxi_tlm_master_socket& master_socket);
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
