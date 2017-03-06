#ifndef AXI_HANDSHAKE_RXTX
#define AXI_HANDSHAKE_RXTX

//Reference
//AMBA® 4 AXI4-Stream Protocol (2.2 Transfer signaling, 2.2.1 Handshake process)
//AMBA® AXI and ACE Protocol Specification
namespace xaxi_tlm{
  class axi_handshake_rx_imp;
  class axi_handshake_tx_imp;

  class xaxi_pa_channel_pins;

  //Single Sample axi receiver
  class axi_handshake_rx{
    public:
      //A slave is permitted to wait for TVALID to be asserted 
      //before asserting the corresponding TREADY.
      axi_handshake_rx( xaxi_pa_channel_pins* p_channel_pins, 
                        bool                  p_tready_waits_for_tvalid);
      ~axi_handshake_rx(); 
      void simulate_single_cycle();

      bool is_handshake_detected();
      
      //If a slave asserts TREADY, it is permitted to deassert
      //TREADY before TVALID is asserted.
      void deassert_tready_and_stop_rx();
      void assert_tready_and_start_rx();

      xaxi_pa_channel_pins* get_sampled_ports();
    protected:
    private:
      axi_handshake_rx_imp *p_imp;
  };
  //Single Sample axi transmitter
  class axi_handshake_tx{
    public:
      //A master is not permitted to wait until TREADY is asserted 
      //before asserting TVALID. Once TVALID is asserted it must
      //remain asserted until the handshake occurs.
      axi_handshake_tx(xaxi_pa_channel_pins* p_channel_pins);
     ~axi_handshake_tx(); 
            xaxi_pa_channel_pins* get_ports();
      void simulate_single_cycle();
      //returns false, if previous data is not yet sampled.
      void transmit_data();
      bool is_previous_data_sampled();
    protected:
    private:
      axi_handshake_tx_imp* p_imp;
  };
};
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
