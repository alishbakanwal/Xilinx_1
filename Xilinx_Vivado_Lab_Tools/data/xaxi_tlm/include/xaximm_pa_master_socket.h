#ifndef XAXIMM_PA_MASTER_SOCKET_H
#define XAXIMM_PA_MASTER_SOCKET_H
#include "xaxi_tlm.h"
namespace xaxi_tlm{
  class xaximm_wr_pa_master_socket_imp;
  class xaximm_rd_pa_master_socket_imp;
  class xaximm_wr_pa_master_socket:
    public xaxi_tlm_slave_base,
    public sc_module
  {
  public:
    //Interface configuration
    xaximm_pa_if_config           aximm_config;
    //Interface pins
    xaximm_wr_addr_ch_pa_pins xaximm_wr_addr_skt_pin_if;
    xaximm_wr_data_ch_pa_pins xaximm_wr_data_skt_pin_if;
    xaximm_wr_resp_ch_pa_pins xaximm_wr_resp_skt_pin_if;

    //Initialize configurations and pins
    xaximm_wr_pa_master_socket(
        sc_core::sc_module_name p_name, 
        xaximm_pa_if_config& p_aximm_config);
    ~xaximm_wr_pa_master_socket();
    void set_master_protocol(xaximm_wr_pa_master_protocol_base* p_xaximm_wr_pa_m_protocol);

    //generate pin accurate signals using attached protocol and queued transactions
    void simulate_single_cycle();

    tlm::tlm_sync_enum
      nb_transport_fw(int socket_id,
          xaxi_tlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t);

    void bind(xaxi_tlm::xaxi_tlm_master_socket& master_socket);
  protected:
  private:
    xaximm_wr_pa_master_socket_imp* p_imp;
    friend class xaxi_tlm_slave_socket;

  };
  class xaximm_rd_pa_master_socket:
    public xaxi_tlm_slave_base,
    public sc_module
  {
  public:
    //Interface configuration
    xaximm_pa_if_config           aximm_config;
    //Interface pins
    xaximm_rd_addr_ch_pa_pins xaximm_rd_addr_skt_pin_if;
    xaximm_rd_data_ch_pa_pins xaximm_rd_data_skt_pin_if;

    //Initialize configurations and pins
    xaximm_rd_pa_master_socket(sc_core::sc_module_name p_name, xaximm_pa_if_config& p_aximm_config);

    ~xaximm_rd_pa_master_socket();
    void set_master_protocol(xaximm_rd_pa_master_protocol_base* p_xaximm_rd_pa_m_protocol);

    //generate pin accurate signals using attached protocol and queued transactions
    void simulate_single_cycle();

    //Receive transactions and put in queue
    tlm::tlm_sync_enum
      nb_transport_fw(int socket_id,
          xaxi_tlm_transaction & trans,
          tlm::tlm_phase & phase,
          sc_core::sc_time & t);

    void bind(xaxi_tlm::xaxi_tlm_master_socket& master_socket);
  protected:
  private:
    xaximm_rd_pa_master_socket_imp* p_imp;
    friend class xaxi_tlm_slave_socket;

  };
  class xaximm_pa_master_socket:public sc_module{
  public:
    xaximm_pa_master_socket(sc_core::sc_module_name p_name,xaximm_pa_if_config& p_aximm_config);
    void set_master_protocol(
        xaximm_wr_pa_master_protocol_base* p_xaximm_wr_pa_m_protocol,
        xaximm_rd_pa_master_protocol_base* p_xaximm_rd_pa_m_protocol
        );

    void bind(xaxi_tlm::xaxi_tlm_master_socket& p_wr_master_socket,
        xaxi_tlm::xaxi_tlm_master_socket& p_rd_master_socket);
    void simulate_single_cycle();

    xaximm_rd_pa_master_socket rd_master_socket;	
    xaximm_wr_pa_master_socket wr_master_socket;
  protected:
  private:
  };

}

#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
