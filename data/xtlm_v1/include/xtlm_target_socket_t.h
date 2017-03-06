#ifndef XTLM_TARGET_SOCKET_T_H
#define XTLM_TARGET_SOCKET_T_H

namespace xtlm_v1{
  template<unsigned int BUSWIDTH = 64>
    class xtlm_target_socket_t:
      public tlm::tlm_target_socket<BUSWIDTH,
      xtlm_protocol_types> {
      public:
        typedef
          tlm::tlm_target_socket<BUSWIDTH,
          xtlm_protocol_types>
            base_type;
        xtlm_target_socket_t():base_type(
            sc_core::sc_gen_unique_name("xtlm_target_socket_t")
            )
        {}
        explicit xtlm_target_socket_t(const char * name):
          base_type(name){
          }

        virtual const char * kind() const{
          return ("xtlm_target_socket_t");
        }
/*
        void invalidate_direct_mem_ptr(sc_dt::uint64 start_range,
            sc_dt::uint64 end_range){
          (* this)->invalidate_direct_mem_ptr(start_range, end_range);
        }
        tlm::tlm_sync_enum
          nb_transport_bw(xtlm_transaction & trans,
              tlm::tlm_phase & phase,
              sc_core::sc_time & t){
            return ((*this)->nb_transport_bw(trans,phase,t));
          }
          */
        using tlm::tlm_target_socket<BUSWIDTH, xtlm_protocol_types>::bind;
        using tlm::tlm_target_socket<BUSWIDTH, xtlm_protocol_types>::operator();
        
        void bind(tlm::tlm_fw_transport_if<xtlm_protocol_types> & iface) {
            base_type::bind(iface);
        }
        /*
        void bind(xtlm_v1::xtlm_initiator_socket_t<BUSWIDTH>& mst_sock_t)
        {
            base_type::bind(mst_sock_t);
        }
        void bind(xtlm_v1::xtlm_target_socket_t<BUSWIDTH>& slv_sock_t)
        {
            base_type::bind(slv_sock_t);
        }
        */
        void operator() (tlm::tlm_fw_transport_if<xtlm_protocol_types> &iface){bind(iface);}
      private:
      };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
