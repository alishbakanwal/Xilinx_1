#ifndef XTLM_V1_MASTER_SOCKET_T_H
#define XTLM_V1_MASTER_SOCKET_T_H
namespace xtlm_v1{
  template<unsigned int BUSWIDTH>
    class xtlm_target_socket_t;
  template<unsigned int BUSWIDTH>
    class xtlm_multi_target_socket_t;
  template<unsigned int BUSWIDTH = 64>
    class xtlm_initiator_socket_t:
      public tlm::tlm_initiator_socket<BUSWIDTH,
      xtlm_protocol_types> {
      public:
        typedef
          tlm::tlm_initiator_socket<BUSWIDTH,
          xtlm_protocol_types>
            base_type;

        xtlm_initiator_socket_t(){
          base_type(sc_core::sc_gen_unique_name("xtlm_initiator_socket_t"));
        }
        explicit xtlm_initiator_socket_t(const char *name):
          base_type(name) 
        {}
        ~xtlm_initiator_socket_t(){}

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
        void bind(tlm::tlm_bw_transport_if<xtlm_protocol_types> &iface){
            base_type::bind(iface);
        }
        void operator() (tlm::tlm_bw_transport_if<xtlm_protocol_types> &iface){
            bind(iface);
        }
        /*
        void bind(xtlm_v1::xtlm_target_socket_t<BUSWIDTH>& slv_sock)
        {
            base_type::bind(slv_sock);
        }
        void bind(xtlm_v1::xtlm_initiator_socket_t<BUSWIDTH>& mst_sock)
        {
            base_type::bind(mst_sock);
        }
        void bind(xtlm_v1::xtlm_multi_target_socket_t<BUSWIDTH>& multi_targ_sock)
        {
            base_type::bind(multi_targ_sock);
        }
        void bind(xtlm_v1::xtlm_simple_target_socket_tagged_t<BUSWIDTH>& simple_targ_sock)
        {
            base_type::bind(simple_targ_sock);
        }
        */
        using tlm::tlm_initiator_socket<BUSWIDTH,xtlm_protocol_types>::bind;
        using tlm::tlm_initiator_socket<BUSWIDTH,xtlm_protocol_types>::operator();
      private:
        //xtlm_mm xtlm_v1_mm; //memory manager
      };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
