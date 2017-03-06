#ifndef XAXIMM_PROTOCOL_EXTENSION_H
#define XAXIMM_PROTOCOL_EXTENSION_H
#include <list>

namespace xtlm_v1{
  class xtlm_aximm_protocol_extension:
    public tlm::tlm_extension<xtlm_aximm_protocol_extension>{
    public:
      xtlm_aximm_protocol_extension():tlm::tlm_extension<xtlm_aximm_protocol_extension>(){
      beat_no = 0;
      addr = 0;
      Aligned_Address = 0;
      aligned = false;
      dtsize = 0;
      Lower_Wrap_Boundary = 0;
      Upper_Wrap_Boundary = 0;
      Lower_Byte_lane = 0;
      Upper_Byte_lane = 0;
      }
      virtual tlm::tlm_extension_base * clone() const{
        xtlm_aximm_protocol_extension* cl = new xtlm_aximm_protocol_extension();
        cl->copy_from(*this);
        return (cl);
      }
      virtual void copy_from(tlm::tlm_extension_base const & ext){
        sc_assert(ID == static_cast<xtlm_aximm_protocol_extension const &>(ext).ID);
        operator =(static_cast<xtlm_aximm_protocol_extension const &>(ext));

        xtlm_aximm_protocol_extension const& xaximm_ext = (static_cast<xtlm_aximm_protocol_extension const &>(ext));
        beat_no = xaximm_ext.beat_no;
        addr  = xaximm_ext.addr;
        Aligned_Address  = xaximm_ext.Aligned_Address;
        aligned = xaximm_ext.aligned;
        dtsize = xaximm_ext.dtsize;
        Lower_Wrap_Boundary = xaximm_ext.Lower_Wrap_Boundary;
        Upper_Wrap_Boundary  = xaximm_ext.Upper_Wrap_Boundary;
        Lower_Byte_lane = xaximm_ext.Lower_Byte_lane;
        Upper_Byte_lane  = xaximm_ext.Upper_Byte_lane;
      }
      unsigned int beat_no;
      unsigned int addr;
      unsigned int Aligned_Address;
      bool aligned;
      unsigned int dtsize;

      unsigned int Lower_Wrap_Boundary;
      unsigned int Upper_Wrap_Boundary;
      unsigned int Lower_Byte_lane;
      unsigned int Upper_Byte_lane;

    protected:
    private:
    };
}
#endif

