#ifndef XAXIMM_PA_PINS
#define XAXIMM_PA_PINS
#include "xaxi_tlm.h"
namespace xaxi_tlm{
  class xaximm_wr_addr_ch_pa_pins:public xaxi_pa_pins_base<13>{
  public:
    xaximm_wr_addr_ch_pa_pins(xaximm_pa_if_config& config);
  protected:
  private:
    xaximm_wr_addr_ch_pa_pins();
  };
  class xaximm_wr_data_ch_pa_pins:public xaxi_pa_pins_base<7>{
  public:
    xaximm_wr_data_ch_pa_pins(xaximm_pa_if_config& config);
  protected:
  private:
    xaximm_wr_data_ch_pa_pins();
  };
  class xaximm_wr_resp_ch_pa_pins:public xaxi_pa_pins_base<5>{
  public:
    xaximm_wr_resp_ch_pa_pins(xaximm_pa_if_config& config);
  protected:
  private:
    xaximm_wr_resp_ch_pa_pins();
  };
  class xaximm_rd_addr_ch_pa_pins:public xaxi_pa_pins_base<13>{
  public:
    xaximm_rd_addr_ch_pa_pins(xaximm_pa_if_config& config);
  protected:
  private:
    xaximm_rd_addr_ch_pa_pins();
  };
  class xaximm_rd_data_ch_pa_pins:public xaxi_pa_pins_base<7>{
  public:
    xaximm_rd_data_ch_pa_pins(xaximm_pa_if_config& config);
  protected:
  private:
    xaximm_rd_data_ch_pa_pins();
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
