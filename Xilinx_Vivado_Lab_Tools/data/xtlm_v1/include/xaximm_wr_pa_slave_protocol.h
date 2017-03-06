#include "xtlm_v1.h"
#ifndef XAXIMM_PA_WR_SLAVE_PROTOCOL_H
#define XAXIMM_PA_WR_SLAVE_PROTOCOL_H

namespace xtlm_v1{
  class xaximm_wr_pa_slave_protocol_imp;
  class xaximm_wr_pa_slave_protocol
    :public xaximm_wr_pa_slave_protocol_base
  {
  public:
    xaximm_wr_pa_slave_protocol();
    ~xaximm_wr_pa_slave_protocol();
    void operator()();
  void init(
      xaximm_pa_if_config* p_aximm_config,
      xaximm_wr_addr_ch_pa_pins* p_xaximm_wr_addr_if,
      xaximm_wr_data_ch_pa_pins* p_xaximm_wr_data_if,
      xaximm_wr_resp_ch_pa_pins* p_xaximm_wr_resp_if,
      xtlm_initiator_socket* p_master_socket
      );
   void transmit_response(
      xtlm_transaction & trans,
      tlm::tlm_phase & phase,
      sc_core::sc_time & t);
   void sample_awid();
   void sample_awaddr();
   void sample_awlen();
   void sample_awsize();
   void sample_awburst();
   void sample_awlock();
   void sample_awcache();
   void sample_awprot();
   void sample_awqos();
   void sample_awregion();
   void sample_awuser();
   void process_wr_addr_channel();
   void set_bresp();
   void sample_wdata();
   void sample_wuser();
   void process_wr_data_channel(); 
  
  private:
    xaximm_wr_pa_slave_protocol_imp* p_imp;

  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
