#ifndef XAXI_PA_PROTOCOL_BASE_H
#define XAXI_PA_PROTOCOL_BASE_H
#include <queue>
#include "xtlm_v1.h"
namespace xtlm_v1{
  enum tr_end_policy { SINGLE_BEAT, FIXED_SIZE, ON_TLAST };

  class xaxi_pa_protocol_base{
  public:
    xaxi_pa_protocol_base(){
      blocked = false;
      reset_in_progress = true;
    }
    //blocks transmission or reception of data stream 
    //by asserting tvalid or tready low until unblock is called
    virtual void block(){blocked = true;}
    void unblock(){blocked = false;}
    bool is_blocked(){return blocked;};

    void start_reset(){reset_in_progress = true;}
    void stop_reset(){reset_in_progress = false;}
  protected:
    bool blocked;
    bool reset_in_progress;
  private:
  };
  class xaxis_pa_master_protocol_base:public xaxi_pa_protocol_base{
  public:
    virtual 	void init(	
        xaxis_pa_if_config* p_stream_config,
        xaxis_pa_pins* pa_stream_if,
        std::queue<xtlm_transaction*>* p_trans_queue) = 0;
    virtual void operator()() = 0;
  protected:
  private:
  };
  class xaxis_pa_slave_protocol_base:public xaxi_pa_protocol_base{
  public:
    virtual	void init(xaxis_pa_if_config* p_stream_config,
        xaxis_pa_pins* p_pa_stream_if,
        xtlm_initiator_socket* p_master_socket
        ) = 0;
    virtual void operator()() = 0;

  protected:
  private:
  };
  class xaximm_wr_pa_master_protocol_base:public xaxi_pa_protocol_base{
  public:
    virtual 	void init(	
        xaximm_pa_if_config* p_stream_config,
        xaximm_wr_addr_ch_pa_pins* xaximm_wr_addr_stream_if,
        xaximm_wr_data_ch_pa_pins* xaximm_wr_data_stream_if,
        xaximm_wr_resp_ch_pa_pins* xaximm_wr_resp_stream_if,
        xtlm_target_socket* p_slave_socket) = 0;
    virtual void operator()() = 0;
    virtual void transmit_transaction(xtlm_transaction& trans, tlm::tlm_phase& phase, sc_core::sc_time& t) = 0;
  protected:
  private:
  };
  class xaximm_rd_pa_master_protocol_base:public xaxi_pa_protocol_base{
  public:
    virtual 	void init(	
        xaximm_pa_if_config* p_stream_config,
        xaximm_rd_addr_ch_pa_pins* xaximm_rd_addr_stream_if,
        xaximm_rd_data_ch_pa_pins* xaximm_rd_data_stream_if,
        xtlm_target_socket* p_slave_socket) = 0;
    virtual void operator()() = 0;
    virtual void transmit_rd_address(xtlm_transaction& trans, tlm::tlm_phase& phase, sc_core::sc_time& t) = 0;
  protected:
  private:
  };
  class xaximm_wr_pa_slave_protocol_base:public xaxi_pa_protocol_base{
  public:
    virtual 	void init(	
        xaximm_pa_if_config* p_stream_config,
        xaximm_wr_addr_ch_pa_pins* xaximm_wr_addr_stream_if,
        xaximm_wr_data_ch_pa_pins* xaximm_wr_data_stream_if,
        xaximm_wr_resp_ch_pa_pins* xaximm_wr_resp_stream_if,
        xtlm_initiator_socket* p_master_socket
        ) = 0;
    virtual void operator()() = 0;
    virtual void transmit_response(
      xtlm_transaction & trans,
      tlm::tlm_phase & phase,
      sc_core::sc_time & t) = 0;
  protected:
  private:
  };
  class xaximm_rd_pa_slave_protocol_base:public xaxi_pa_protocol_base{
  public:
    virtual 	void init(	
        xaximm_pa_if_config* p_stream_config,
        xaximm_rd_addr_ch_pa_pins* xaximm_rd_addr_stream_if,
        xaximm_rd_data_ch_pa_pins* xaximm_rd_data_stream_if,
        xtlm_initiator_socket* p_master_socket
        ) = 0;
    virtual void operator()() = 0;
    virtual void transmit_response(
        xtlm_transaction & trans,
        tlm::tlm_phase & phase,
        sc_core::sc_time & t) = 0;
  protected:
  private:
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
