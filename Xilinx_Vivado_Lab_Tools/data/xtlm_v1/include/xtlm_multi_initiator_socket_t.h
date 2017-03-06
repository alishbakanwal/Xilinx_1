#ifndef XTLM_V1_MULTI_INTIATOR_SOCKET_T_H
#define XTLM_V1_MULTI_INTIATOR_SOCKET_T_H
namespace xtlm_v1{
  template<unsigned int BUSWIDTH>
    class xtlm_target_socket_t;
  template<unsigned int BUSWIDTH>
    class xtlm_multi_target_socket_t;
  template<unsigned int BUSWIDTH = 64>
    class xtlm_multi_initiator_socket_t:
      public tlm_utils::multi_passthrough_initiator_socket<xtlm_v1::xtlm_bw_transport_if<>,BUSWIDTH,
      xtlm_protocol_types> {
      public:
        typedef
          tlm_utils::multi_passthrough_initiator_socket<xtlm_v1::xtlm_bw_transport_if<>,BUSWIDTH,
      xtlm_protocol_types>
            base_type;

        xtlm_multi_initiator_socket_t(){
          base_type(sc_core::sc_gen_unique_name("xtlm_multi_initiator_socket_t"));
        }
        explicit xtlm_multi_initiator_socket_t(const char *name):
          base_type(name) 
        {}
        ~xtlm_multi_initiator_socket_t(){}

        virtual const char * kind() const{
          return ("xtlm_initiator_socket_t");
        }
/*
        void b_transport(xtlm_transaction & trans,
            sc_core::sc_time & t){
          (* this)->b_transport(trans, t);
        }
        
        unsigned int transport_dbg(xtlm_transaction & trans){
          return ((* this)->transport_dbg(trans));
        }

        bool get_direct_mem_ptr(xtlm_transaction &trans, tlm::tlm_dmi &dmi_data){
          return ((* this)->get_direct_mem_ptr(trans, dmi_data));
        }
        tlm::tlm_sync_enum
          nb_transport_fw(xtlm_transaction & trans,
              tlm::tlm_phase & phase,
              sc_core::sc_time & t){
            return ((*this)->nb_transport_fw(trans,phase,t));
          }
          */
/*
        using tlm::tlm_initiator_socket<BUSWIDTH,
              xtlm_protocol_types>::bind;
        using tlm::tlm_initiator_socket_tagged<BUSWIDTH,
              xtlm_protocol_types>::operator();
              */
        void bind(xtlm_v1::xtlm_bw_transport_if<> &iface){
            this->register_invalidate_direct_mem_ptr(& iface,
              &xtlm_v1::xtlm_bw_transport_if<>::invalidate_direct_mem_ptr);
            this->register_nb_transport_bw(& iface,
              &xtlm_v1::xtlm_bw_transport_if<>::nb_transport_bw);
        }
        void operator() (xtlm_v1::xtlm_bw_transport_if<> &iface){
          bind(iface);
        }
        void bind(xtlm_v1::xtlm_target_socket_t<BUSWIDTH>& slv_sock)
        {
            base_type::bind(slv_sock);
        }
        void bind(xtlm_v1::xtlm_multi_initiator_socket_t<BUSWIDTH>& multi_initiator_sock_t)
        {
            base_type::bind(multi_initiator_sock_t);
        }
        void bind(xtlm_v1::xtlm_multi_target_socket_t<BUSWIDTH>& multi_target_sock_t)
        {
            base_type::bind(multi_target_sock_t);
        }
      private:
        //xtlm_mm xtlm_v1_mm; //memory manager
      };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
