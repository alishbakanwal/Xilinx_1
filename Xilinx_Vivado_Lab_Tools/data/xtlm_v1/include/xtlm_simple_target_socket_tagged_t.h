#ifndef XAXI_TLM_SIMPLE_TARGET_SOCKET_TAGGED_T_H
#define XAXI_TLM_SIMPLE_TARGET_SOCKET_TAGGED_T_H

namespace xtlm_v1{
  template<unsigned int BUSWIDTH = 64>
    class xtlm_simple_target_socket_tagged_t:
      public xtlm_socket_base,
      public tlm_utils::simple_target_socket_tagged<xtlm_fw_transport_if<>,
      BUSWIDTH,
      xtlm_protocol_types> {
      public:
        typedef
          tlm_utils::simple_target_socket_tagged<xtlm_fw_transport_if<>,
          BUSWIDTH,
          xtlm_protocol_types>
            base_type;
        xtlm_simple_target_socket_tagged_t():base_type(
            sc_core::sc_gen_unique_name("xtlm_simple_target_socket_tagged_t")
            )
        {}
        explicit xtlm_simple_target_socket_tagged_t(const char * name, int socket_id= 0):
          xtlm_socket_base(socket_id),
          base_type(name){
          }

        virtual const char * kind() const{
          return ("xtlm_simple_target_socket_tagged_t");
        }

        void invalidate_direct_mem_ptr(int socket_id,
            sc_dt::uint64 start_range,
            sc_dt::uint64 end_range){
          (* this)->invalidate_direct_mem_ptr(start_range, end_range);
        }
        void invalidate_direct_mem_ptr(sc_dt::uint64 start_range, sc_dt::uint64 end_range){
          invalidate_direct_mem_ptr(0, start_range, end_range);		
        }
        tlm::tlm_sync_enum
          nb_transport_bw(int socket_id,
              xtlm_transaction & trans,
              tlm::tlm_phase & phase,
              sc_core::sc_time & t){
            return ((*this)->nb_transport_bw(trans,phase,t));
          }
        tlm::tlm_sync_enum
          nb_transport_bw(xtlm_transaction & trans,
              tlm::tlm_phase & phase,
              sc_core::sc_time & t){
            return nb_transport_bw(0,trans,phase,t);
          }
        using tlm_utils::simple_target_socket_tagged<xtlm_fw_transport_if<>,
              BUSWIDTH,
              xtlm_protocol_types>::bind;
        using tlm_utils::simple_target_socket_tagged<xtlm_fw_transport_if<>,
              BUSWIDTH,
              xtlm_protocol_types>::operator();
        void bind(xtlm_fw_transport_if<> & iface) {
          this->register_b_transport(& iface,
              & xtlm_fw_transport_if<>::b_transport,
              this->get_socket_id());
          this->register_transport_dbg(& iface,
              & xtlm_fw_transport_if<>::transport_dbg,
              this->get_socket_id());
          this->register_get_direct_mem_ptr(& iface,
              &xtlm_fw_transport_if<>::get_direct_mem_ptr,
              this->get_socket_id());
          this->register_nb_transport_fw(& iface,
              & xtlm_fw_transport_if<>::nb_transport_fw,
              this->get_socket_id());
        }
        void operator() (xtlm_fw_transport_if<> &iface){bind(iface);}
      private:
      };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
