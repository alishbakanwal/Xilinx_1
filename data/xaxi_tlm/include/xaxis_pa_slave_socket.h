#ifndef XAXI_PA_SLAVE_SOCKET_H
#define XAXI_PA_SLAVE_SOCKET_H
#include "xaxi_tlm.h"
namespace xaxi_tlm{
  class xaxis_pa_slave_socket
    :public sc_module{
    public:
      //Interface configuration
      xaxis_pa_if_config           stream_config;
      //Interface pins
      xaxis_pa_pins xaxis_skt_pin_if;

      //Initialize configurations and pins
      xaxis_pa_slave_socket(sc_core::sc_module_name p_name,xaxis_pa_if_config& p_stream_config):
        stream_config(p_stream_config),
        xaxis_skt_pin_if(p_stream_config),
        sc_module(p_name)
      {
        master_socket = new xaxi_tlm_master_socket(
            sc_core::sc_gen_unique_name((std::string((const char*)p_name) + std::string("_master_socket")).c_str()),
            stream_config.get_tdata_width());
      }


      void set_slave_protocol(xaxis_pa_slave_protocol_base* p_pa_slave_protocol){
        pa_slave_protocol = p_pa_slave_protocol;
        (*pa_slave_protocol).init(&stream_config, &xaxis_skt_pin_if, master_socket);
      }

      //generate pin accurate signals using attached protocol and queued transactions
      void simulate_single_cycle(){
        (*pa_slave_protocol)();
      }

      //Receive transactions and put in queue
      /*void b_transport(int socket_id,
        xaxi_tlm::xaxi_tlm_transaction & trans,
        sc_core::sc_time & time);
       */

      void bind(xaxi_tlm::xaxi_tlm_slave_socket& slave_socket){
        slave_socket.bind(*master_socket);
      }
    protected:
    private:
      //protocol
      xaxis_pa_slave_protocol_base* pa_slave_protocol;

      //TLM slave_socket to bind with master TLM socket
      xaxi_tlm_master_socket* master_socket;
      friend class xaxi_tlm_master_socket;


    };
}

#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
