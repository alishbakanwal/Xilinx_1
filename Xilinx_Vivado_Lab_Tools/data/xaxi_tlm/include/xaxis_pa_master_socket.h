#ifndef XAXI_PA_MASTER_SOCKET_H
#define XAXI_PA_MASTER_SOCKET_H
#include "xaxi_tlm.h"
namespace xaxi_tlm{
  class xaxis_pa_master_socket:
    public xaxi_tlm_slave_base,
    public sc_module
  {
  public:
    //Interface configuration
    xaxis_pa_if_config           stream_config;
    //Interface pins
    xaxis_pa_pins xaxis_skt_pin_if;

    //Initialize configurations and pins
    xaxis_pa_master_socket(sc_core::sc_module_name p_name, xaxis_pa_if_config& p_stream_config):
      stream_config(p_stream_config),
      xaxis_skt_pin_if(p_stream_config),
      xaxi_tlm::xaxi_tlm_slave_base("pa_master_socket_base"),
      sc_module(p_name)
    {
      slave_socket = new xaxi_tlm_slave_socket(
          sc_core::sc_gen_unique_name((std::string((const char*)p_name) + std::string("_slave_socket")).c_str()),
          stream_config.get_tdata_width()
          );

      //Register b_transport interface			
      (*slave_socket)(*this);
    }

    void set_master_protocol(xaxis_pa_master_protocol_base* p_pa_master_protocol){
      pa_master_protocol = p_pa_master_protocol;
      (*pa_master_protocol).init(&stream_config, &xaxis_skt_pin_if, &trans_queue);
    }

    //generate pin accurate signals using attached protocol and queued transactions
    void simulate_single_cycle(){
      (*pa_master_protocol)();
    }

    //Receive transactions and put in queue
    void b_transport(int socket_id,
        xaxi_tlm::xaxi_tlm_transaction & trans,
        sc_core::sc_time & time){
      //cout << "pa_master_socket::" << __FUNCTION__ << endl;
      xaxi_tlm_transaction* t = new xaxi_tlm_transaction();

      if(stream_config.is_tdata_enabled()){
        unsigned char* data_ptr = new unsigned char[trans.get_data_length()];
        t->set_data_ptr(data_ptr);
      }
      if(stream_config.is_tstrb_enabled()){
        unsigned char* byte_en_ptr = new unsigned char[trans.get_byte_enable_length()];
        t->set_byte_enable_ptr(byte_en_ptr);
      }

      t->deep_copy_from(trans);
      trans_queue.push(t);
    }

    void bind(xaxi_tlm::xaxi_tlm_master_socket& master_socket){
      master_socket.bind(*slave_socket);
    }
  protected:
  private:
    //protocol
    xaxis_pa_master_protocol_base* pa_master_protocol;

    //TLM slave_socket to bind with master TLM socket
    xaxi_tlm_slave_socket* slave_socket;
    friend class xaxi_tlm_slave_socket;

    //transaction queue
    std::queue<xaxi_tlm_transaction*> trans_queue;
  };
}

#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
