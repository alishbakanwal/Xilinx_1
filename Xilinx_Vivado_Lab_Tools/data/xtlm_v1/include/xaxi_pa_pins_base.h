#ifndef XAXI_PA_PINS_IF_BASE
#define XAXI_PA_PINS_IF_BASE
#include "xtlm_v1.h"
namespace xtlm_v1{
  class xaxi_pa_channel_pins{
  public:
    virtual int get_no_of_pins() = 0;
    virtual void set_pin_val(unsigned int PIN_ENUM, unsigned int val) = 0;
    virtual unsigned int get_pin_val(unsigned int PIN_ENUM) = 0;
    //virtual xsc::xsc_bv& get_pin(unsigned int PIN_ENUM) = 0;
    virtual hls::APBase& get_pin(unsigned int PIN_ENUM) = 0;
  protected:
  private:
  };

  template<int no_of_pins>
    class xaxi_pa_pins_base:public xaxi_pa_channel_pins{
    public:
      xaxi_pa_pins_base(){
        for(int i = 0;i < no_of_pins;i++){
          pins[i] = NULL;
        }
      }
      ~xaxi_pa_pins_base(){
        for(int i = 0;i < no_of_pins;i++){
          delete pins[i];
        }
      }
      int get_no_of_pins(){
        return no_of_pins;
      }
      void set_pin_val(unsigned int PIN_ENUM, unsigned int val){
       if(pins[PIN_ENUM] == NULL)
       {
         if(PIN_ENUM == XAXIMM_ENUM_ARLOCK || PIN_ENUM == XAXIMM_ENUM_AWLOCK){
            std::cerr << "Warning : Lock pin is not supported in AXI4. Write failed";
         }else{
            std::cerr << "Internal Error : Attempt to write non-existing pin at index " << no_of_pins << " " << PIN_ENUM;
            exit(1);
         }
       }
       else
       {
            //assert(pins[PIN_ENUM] != NULL);
            assert(pins[PIN_ENUM]->length() <= 32);
            //*(pins[PIN_ENUM]) = val;
            pins[PIN_ENUM]->set_pVal(0,(uint64_t)val);
       }
      }
      unsigned int get_pin_val(unsigned int PIN_ENUM){ 
       if(pins[PIN_ENUM] == NULL)
       {
         if(PIN_ENUM == XAXIMM_ENUM_ARLOCK || PIN_ENUM == XAXIMM_ENUM_AWLOCK){
            std::cerr << "Warning : Lock pin is not supported in AXI4. Read failed." ;
         }else{
            std::cerr << "Internal Error : Attempt to read non-existing pin. " << no_of_pins << " " << PIN_ENUM;
            exit(1);
         }
       }
       else
       {
            //assert(pins[PIN_ENUM] != NULL);
            assert(pins[PIN_ENUM]->length() <= 32);
            return pins[PIN_ENUM]->to_uint();
       }
       return 0;//coverity issue
      }
      hls::APBase& get_pin(unsigned int PIN_ENUM){
        assert(pins[PIN_ENUM] != NULL);
        return *(pins[PIN_ENUM]);
      }
    protected:
      hls::APBase* pins[no_of_pins];
    private:
    };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
