#ifndef XAXIS_PA_PINS
#define XAXIS_PA_PINS
#include "xaxi_tlm.h"
namespace xaxi_tlm{
  class xaxis_pa_pins:public xaxi_pa_pins_base<8>{
  public:
    xaxis_pa_pins(xaxis_pa_if_config& config){

      pins[XAXIS_ENUM_TVALID] = new xsc::xsc_bv(1,0);

      if(config.is_tready_enabled()){
        pins[XAXIS_ENUM_TREADY] = 
          new xsc::xsc_bv(config.get_tready_width(),0);
      }
      if(config.is_tdata_enabled()){
        pins[XAXIS_ENUM_TDATA] = new xsc::xsc_bv(config.get_tdata_width(),0);
      }
      if(config.is_tstrb_enabled()){
        pins[XAXIS_ENUM_TSTRB] = 
          new xsc::xsc_bv(config.get_tstrb_width(),0);
      }
      if(config.is_tlast_enabled()){
        pins[XAXIS_ENUM_TLAST] = 
          new xsc::xsc_bv(config.get_tlast_width(),0);
      }
      if(config.is_tid_enabled()){
        pins[XAXIS_ENUM_TID] = 
          new xsc::xsc_bv(config.get_tid_width(),0);
      }
      if(config.is_tdest_enabled()){
        pins[XAXIS_ENUM_TDEST] = 
          new xsc::xsc_bv(config.get_tdest_width(),0);
      }
      if(config.is_tuser_enabled()){
        pins[XAXIS_ENUM_TUSER] = 
          new xsc::xsc_bv(config.get_tuser_width(),0);
      }
    }
  protected:
  private:
    xaxis_pa_pins();
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
