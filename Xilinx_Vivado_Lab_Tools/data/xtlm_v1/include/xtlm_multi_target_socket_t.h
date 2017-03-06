#ifndef XTLM_V1_MULTI_TARGET_SOCKET_T_H
#define XTLM_V1_MULTI_TARGET_SOCKET_T_H

namespace xtlm_v1{
  template<unsigned int BUSWIDTH = 64>
    class xtlm_multi_target_socket_t:
      public tlm_utils::multi_passthrough_target_socket< xtlm_v1::xtlm_fw_transport_if<>,BUSWIDTH,xtlm_protocol_types> {
      public:
        typedef
          tlm_utils::multi_passthrough_target_socket<xtlm_v1::xtlm_fw_transport_if<>,BUSWIDTH,
      xtlm_protocol_types>
            base_type;
        xtlm_multi_target_socket_t():base_type(
            sc_core::sc_gen_unique_name("xtlm_multi_target_socket_t")
            )
        {}
        explicit xtlm_multi_target_socket_t(const char * name):
          base_type(name){
          }

        virtual const char * kind() const{
          return ("xtlm_multi_target_socket_t");
        }
        void bind(xtlm_v1::xtlm_fw_transport_if<>& iface) {
            this->register_b_transport(& iface,
                & xtlm_fw_transport_if<>::b_transport);
            this->register_transport_dbg(& iface,
                & xtlm_fw_transport_if<>::transport_dbg);
            this->register_get_direct_mem_ptr(& iface,
                &xtlm_fw_transport_if<>::get_direct_mem_ptr);
            this->register_nb_transport_fw(& iface,
                & xtlm_fw_transport_if<>::nb_transport_fw);
        }
        void bind(xtlm_v1::xtlm_multi_target_socket_t<BUSWIDTH>& slv_sock_t)
        {
            base_type::bind(slv_sock_t);
        }
        void operator() (xtlm_v1::xtlm_fw_transport_if<>& iface){bind(iface);}
      private:
      };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
