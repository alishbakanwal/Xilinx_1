#include "xtlm_v1.h"
#ifndef XAXIMM_PA_RD_MASTER_PROTOCOL_H
#define XAXIMM_PA_RD_MASTER_PROTOCOL_H

namespace xtlm_v1{
  class xaximm_rd_pa_master_protocol_imp;
  class xaximm_rd_pa_master_protocol:
    public xaximm_rd_pa_master_protocol_base
  {
  public:
    xaximm_rd_pa_master_protocol();
    ~xaximm_rd_pa_master_protocol();
    void init(	xaximm_pa_if_config* p_aximm_config,
        xaximm_rd_addr_ch_pa_pins* p_xaximm_rd_addr_if,
        xaximm_rd_data_ch_pa_pins* p_xaximm_rd_data_if,
        xtlm_target_socket* p_slave_socket
        );
    void operator()();
  private:
    void transmit_rd_address(xtlm_transaction& trans, tlm::tlm_phase& phase, sc_core::sc_time& t);
    void set_raddr();
    void set_arid();
    void set_arlen();
    void set_arsize();
    void set_arburst();
    void set_arlock();
    void set_arcache();
    void set_arprot();
    void set_arqos();
    void set_aruser();
    void set_arregion();
    void sample_rdata(xtlm_transaction*& trans);
    void sample_ruser(xtlm_transaction*& trans);
    void sample_rresp(xtlm_transaction*& trans);
    void process_rd_data_channel();
    void process_rd_addr_channel();

    xaximm_rd_pa_master_protocol_imp* p_imp;
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
