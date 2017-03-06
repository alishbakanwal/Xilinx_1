#include "xaxi_tlm.h"
#ifndef XAXIMM_PA_WR_MASTER_PROTOCOL_H
#define XAXIMM_PA_WR_MASTER_PROTOCOL_H

namespace xaxi_tlm{
  class xaximm_wr_pa_master_protocol_imp;
  class xaximm_wr_pa_master_protocol
    :public xaximm_wr_pa_master_protocol_base
  {
  public:
    xaximm_wr_pa_master_protocol();
    ~xaximm_wr_pa_master_protocol();
    void init(
        xaximm_pa_if_config* p_aximm_config,
        xaximm_wr_addr_ch_pa_pins* p_xaximm_wr_addr_if,
        xaximm_wr_data_ch_pa_pins* p_xaximm_wr_data_if,
        xaximm_wr_resp_ch_pa_pins* p_xaximm_wr_resp_if,
        xaxi_tlm_slave_socket* p_slave_socket);
    void operator()();
    void transmit_transaction(int socket_id,xaxi_tlm_transaction& trans, tlm::tlm_phase& phase, sc_core::sc_time& t);
  private:
    xaximm_wr_pa_master_protocol_imp* p_imp; 
    void set_awaddr();
    void set_awid();
    void set_awlen();
    void set_awsize();
    void set_awburst();
    void set_awcache();
    void set_awlock();
    void set_awprot();
    void set_awqos();
    void set_awuser();
    void set_wdata();
    void set_wlast();
    void set_wuser();
    void sample_bresp();
    void sample_buser();
    void process_wr_addr_channel();
    void process_wr_data_channel();
    void process_wr_resp_channel();

  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
