#include "xtlm_v1.h"
#ifndef XAXI_PA_STREAMING_PROTOCOL_H
#define XAXI_PA_STREAMING_PROTOCOL_H

namespace xtlm_v1{
  class xaxis_pa_master_protocol_imp;
  class xaxis_pa_master_protocol:
    public xaxis_pa_master_protocol_base
  {
  public:
    xaxis_pa_master_protocol(tr_end_policy p_tr_end_policy);
    ~xaxis_pa_master_protocol();
    void init(	xaxis_pa_if_config* p_stream_config,
        xaxis_pa_pins* p_pa_stream_if,
        std::queue<xtlm_transaction*>* p_trans_queue
        );

    void set_packet_size(int size);

    void operator()();
    void check_extension(xtlm_transaction* p_tr);
    void set_tdata();
    void set_tstrb();
    void set_tid();
    void set_tdest();
    void set_tuser();
  private:

    xaxis_pa_master_protocol_imp *p_imp;
  };
  
  class xaxis_pa_slave_protocol_imp;
  class xaxis_pa_slave_protocol:
    public xaxis_pa_slave_protocol_base
  {
  public:
    xaxis_pa_slave_protocol(tr_end_policy p_tr_end_policy);
    void init(	xaxis_pa_if_config* p_stream_config,
        xaxis_pa_pins* p_pa_stream_if,
        xtlm_initiator_socket* p_master_socket
        );
    void set_packet_size(int size);
    ~xaxis_pa_slave_protocol();
    void operator()();
    void sample_tdata();
    void sample_tstrb();
    void sample_tid();
    void sample_tdest();
    void sample_tuser();
    //TKEEP in not supported in Xilinx.
    //void sample_tkeep();

  private:
  xaxis_pa_slave_protocol_imp *p_imp;
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
