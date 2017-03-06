#ifndef XTLM_V1_STREAM_EXTENSION_H
#define XTLM_V1_STREAM_EXTENSION_H
#include <list>
namespace xtlm_v1{
  class xtlm_axistream_extension:
    public tlm::tlm_extension<xtlm_axistream_extension>{
    public:
      xtlm_axistream_extension():tlm::tlm_extension<xtlm_axistream_extension>(){
        sample_no = 0;
        id = 0;
      }
      virtual tlm::tlm_extension_base * clone() const{
        xtlm_axistream_extension* cl = new xtlm_axistream_extension();
        cl->sample_no = sample_no;
        cl->tid.insert(cl->tid.begin(),tid.begin(),tid.end());
        cl->tdest.insert(cl->tdest.begin(),tdest.begin(),tdest.end());
        cl->tuser.insert(cl->tuser.begin(),tuser.begin(),tuser.end());
        return (cl);
      }
      virtual void copy_from(tlm::tlm_extension_base const & ext){
        sc_assert(ID == static_cast<xtlm_axistream_extension const &>(ext).ID);
        operator =(static_cast<xtlm_axistream_extension const &>(ext));
      }
      unsigned int sample_no;
      std::list<unsigned int> tid;
      std::list<unsigned int> tdest;
      //std::list<xsc::xsc_bv> tuser;
      std::list<hls::APBase> tuser;
      unsigned int id;
    protected:
    private:
    };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
