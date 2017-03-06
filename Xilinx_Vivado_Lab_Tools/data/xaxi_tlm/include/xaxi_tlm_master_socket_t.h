#ifndef XAXI_TLM_MASTER_SOCKET_T_H
#define XAXI_TLM_MASTER_SOCKET_T_H
namespace xaxi_tlm{
  template<unsigned int BUSWIDTH = 64>
    class xaxi_tlm_master_socket_t:
      public xaxi_tlm_socket_base,
      public tlm_utils::simple_initiator_socket_tagged<xaxi_tlm_bw_transport_if,
      BUSWIDTH,
      xaxi_tlm_protocol_types> {
      public:
        typedef
          tlm_utils::simple_initiator_socket_tagged<xaxi_tlm_bw_transport_if,
          BUSWIDTH,
          xaxi_tlm_protocol_types>
            base_type;

        xaxi_tlm_master_socket_t(){
          base_type(sc_core::sc_gen_unique_name("xaxi_tlm_master_socket_t"));
        }
        explicit xaxi_tlm_master_socket_t(const char *name, int socket_id = 0):
          xaxi_tlm_socket_base(socket_id),
          base_type(name) 
        {}
        ~xaxi_tlm_master_socket_t(){}

        virtual const char * kind() const{
          return ("xaxi_tlm_master_socket_t");
        }

        void b_transport(int socket_id,
            xaxi_tlm_transaction & trans,
            sc_core::sc_time & t){
          (* this)->b_transport(trans, t);
        }
        void b_transport(xaxi_tlm_transaction & trans, sc_core::sc_time & time){
          b_transport(0,trans,time);
        }

        unsigned int transport_dbg(int socket_id,
            xaxi_tlm_transaction & trans){
          return ((* this)->transport_dbg(trans));
        }
        unsigned int transport_dbg(xaxi_tlm_transaction & trans){
          return transport_dbg(0, trans);
        }

        bool get_direct_mem_ptr(int, xaxi_tlm_transaction &trans, tlm::tlm_dmi &dmi_data){
          return ((* this)->get_direct_mem_ptr(trans, dmi_data));
        }
        bool get_direct_mem_ptr(xaxi_tlm_transaction & trans, tlm::tlm_dmi & tlmdmi){
          return get_direct_mem_ptr(0, trans,tlmdmi);
        }
        tlm::tlm_sync_enum
          nb_transport_fw(int socket_id,
              xaxi_tlm_transaction & trans,
              tlm::tlm_phase & phase,
              sc_core::sc_time & t){
            return ((*this)->nb_transport_fw(trans,phase,t));
          }
        tlm::tlm_sync_enum
          nb_transport_fw(
              xaxi_tlm_transaction & trans,
              tlm::tlm_phase & phase,
              sc_core::sc_time & t){
            return nb_transport_fw(0,trans,phase,t);
          }

        using tlm_utils::simple_initiator_socket_tagged<xaxi_tlm_bw_transport_if,
              BUSWIDTH,
              xaxi_tlm_protocol_types>::bind;
        using tlm_utils::simple_initiator_socket_tagged<xaxi_tlm_bw_transport_if,
              BUSWIDTH,
              xaxi_tlm_protocol_types>::operator();
        void bind(xaxi_tlm_bw_transport_if &iface){
          this->register_invalidate_direct_mem_ptr(& iface,

              &xaxi_tlm_bw_transport_if::invalidate_direct_mem_ptr,
              this->get_socket_id());
          this->register_nb_transport_bw(& iface,
              &xaxi_tlm_bw_transport_if::nb_transport_bw,
              this->get_socket_id());
        }
        void operator() (xaxi_tlm_bw_transport_if &iface){
          bind(iface);
        }
      private:
        //xaximm_tlm_mm_if xaxi_tlm_mm; //memory manager
      };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
