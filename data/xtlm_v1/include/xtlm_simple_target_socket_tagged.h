#ifndef XAXI_TLM_SIMPLE_TARGET_SOCKET_TAGGED_H
#define XAXI_TLM_SIMPLE_TARGET_SOCKET_TAGGED_H

namespace xtlm_v1{

  //Forward declaration
  class xtlm_simple_initiator_socket_tagged;
  class xtlm_simple_target_socket_tagged_imp;
  
  class xtlm_simple_target_socket_tagged
  {
  private:
    xtlm_simple_target_socket_tagged_imp* p_imp;
    /***Changing templated instance is not allowed since there is lifetime dependemcy***/
    sc_core::sc_object* get_slave_socket_instance(std::string& socket_name,int width,int socket_id);
  public:
    std::string name();
       xtlm_simple_target_socket_tagged(std::string slave_socket_name_p, int width_p, int socket_id = 0);

       ~xtlm_simple_target_socket_tagged();
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
          xtlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t);
    tlm::tlm_sync_enum
      nb_transport_bw(xtlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t){
        return (nb_transport_bw(0,trans,phase,t));
      }

    void bind(xtlm_fw_transport_if<> & iface) ;
    void operator() (xtlm_fw_transport_if<> &iface){bind(iface);}

    void bind(xtlm_v1::xtlm_simple_initiator_socket_tagged& master_socket);
    void operator() (xtlm_v1::xtlm_simple_initiator_socket_tagged& master_socket){bind(master_socket);}

    void bind(xtlm_v1::xtlm_initiator_socket& si_master_socket);
    void operator() (xtlm_v1::xtlm_initiator_socket& si_master_socket){bind(si_master_socket);}
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
