#include <vector>
#ifndef XAXI_TLM_MM_IF
#define XAXI_TLM_MM_IF
namespace xaxi_tlm{
  class xaximm_tlm_mm_if:public virtual tlm::tlm_mm_interface{
  public:
    xaximm_tlm_mm_if();
    ~xaximm_tlm_mm_if();
    static xaximm_tlm_mm_if* get_instance();

    xaxi_tlm_transaction* get_trans_object();
    void free(xaxi_tlm_transaction*);
    xaximm_protocol_extension* get_protocol_extension();
  protected:
  private:
    std::vector<xaxi_tlm_transaction* > m_trans_pool;
    std::vector<xaximm_protocol_extension* > m_protocol_extension_pool;
    static xaximm_tlm_mm_if* instance;
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
