#include "xaxi_tlm.h"
#ifndef XAXIMM_PA_RD_SLAVE_PROTOCOL_H
#define XAXIMM_PA_RD_SLAVE_PROTOCOL_H

namespace xaxi_tlm{
  class xaximm_rd_pa_slave_protocol_imp;
  class xaximm_rd_pa_slave_protocol:
    public xaximm_rd_pa_slave_protocol_base
  {
  public:
    xaximm_rd_pa_slave_protocol();
    void init(	xaximm_pa_if_config* p_aximm_config,
        xaximm_rd_addr_ch_pa_pins* p_xaximm_rd_addr_if,
        xaximm_rd_data_ch_pa_pins* p_xaximm_rd_data_if,
        xaxi_tlm_master_socket* p_master_socket
        );
    ~xaximm_rd_pa_slave_protocol();
    void block();
    void operator()();
    void transmit_response(
        int socket_id,
        xaxi_tlm_transaction & trans,
        tlm::tlm_phase & phase,
        sc_core::sc_time & t);
  private:
    xaximm_rd_pa_slave_protocol_imp* p_imp;
    void 	sample_arid();
    void 	sample_araddr();
    void 	sample_arlen();
    void 	sample_arsize();
    void 	sample_arburst();
    void 	sample_arlock();
    void 	sample_arcache();
    void 	sample_arprot();
    void 	sample_arqos();
    void 	sample_arregion();
    void 	sample_aruser();
    void 	process_rd_addr_channel();

    void 	set_rid();
    void 	set_rdata();
    void 	set_rresp();
    void 	set_rlast();
    void 	set_ruser();
    void 	process_rd_data_channel();
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
