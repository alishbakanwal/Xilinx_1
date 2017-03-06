#ifndef XAXI_TLM_SIMPLE_INITIATOR_SOCKET_TAGGED_T_H
#define XAXI_TLM_SIMPLE_INITIATOR_SOCKET_TAGGED_T_H
namespace xtlm_v1{
  template<unsigned int BUSWIDTH = 64>
    class xtlm_simple_initiator_socket_tagged_t:
      public xtlm_socket_base,
      public tlm_utils::simple_initiator_socket_tagged<xtlm_bw_transport_if<>,
      BUSWIDTH,
      xtlm_protocol_types> {
      public:
        typedef
          tlm_utils::simple_initiator_socket_tagged<xtlm_bw_transport_if<>,
          BUSWIDTH,
          xtlm_protocol_types>
            base_type;

        xtlm_simple_initiator_socket_tagged_t(){
          base_type(sc_core::sc_gen_unique_name("xtlm_simple_initiator_socket_tagged_t"));
        }
        explicit xtlm_simple_initiator_socket_tagged_t(const char *name, int socket_id = 0):
          xtlm_socket_base(socket_id),
          base_type(name) 
        {}
        ~xtlm_simple_initiator_socket_tagged_t(){}

        virtual const char * kind() const{
          return ("xtlm_simple_initiator_socket_tagged_t");
        }
/*
        void b_transport(int socket_id,
            xtlm_transaction & trans,
            sc_core::sc_time & t){
          (* this)->b_transport(trans, t);
        }
        void b_transport(xtlm_transaction & trans, sc_core::sc_time & time){
          b_transport(0,trans,time);
        }

        unsigned int transport_dbg(int socket_id,
            xtlm_transaction & trans){
          return ((* this)->transport_dbg(trans));
        }
        unsigned int transport_dbg(xtlm_transaction & trans){
          return transport_dbg(0, trans);
        }

        bool get_direct_mem_ptr(int, xtlm_transaction &trans, tlm::tlm_dmi &dmi_data){
          return ((* this)->get_direct_mem_ptr(trans, dmi_data));
        }
        bool get_direct_mem_ptr(xtlm_transaction & trans, tlm::tlm_dmi & tlmdmi){
          return get_direct_mem_ptr(0, trans,tlmdmi);
        }
        tlm::tlm_sync_enum
          nb_transport_fw(int socket_id,
              xtlm_transaction & trans,
              tlm::tlm_phase & phase,
              sc_core::sc_time & t){
            return ((*this)->nb_transport_fw(trans,phase,t));
          }
        tlm::tlm_sync_enum
          nb_transport_fw(
              xtlm_transaction & trans,
              tlm::tlm_phase & phase,
              sc_core::sc_time & t){
            return nb_transport_fw(0,trans,phase,t);
          }
*/
        using tlm_utils::simple_initiator_socket_tagged<xtlm_bw_transport_if<>,
              BUSWIDTH,
              xtlm_protocol_types>::bind;
        using tlm_utils::simple_initiator_socket_tagged<xtlm_bw_transport_if<>,
              BUSWIDTH,
              xtlm_protocol_types>::operator();
        void bind(xtlm_bw_transport_if<> &iface){
          this->register_invalidate_direct_mem_ptr(& iface,
              &xtlm_bw_transport_if<>::invalidate_direct_mem_ptr,
              this->get_socket_id());
          this->register_nb_transport_bw(& iface,
              &xtlm_bw_transport_if<>::nb_transport_bw,
              this->get_socket_id());
        }
        void operator() (xtlm_bw_transport_if<> &iface){
          bind(iface);
        }
      private:
        //xaximm_tlm_mm_if xtlm_mm; //memory manager
      };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
