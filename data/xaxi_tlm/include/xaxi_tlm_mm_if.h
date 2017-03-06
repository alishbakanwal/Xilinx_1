#include <vector>
#ifndef XAXI_TLM_MM_IF
#define XAXI_TLM_MM_IF
namespace xaxi_tlm{
  class xaxi_tlm_mm_if:public virtual tlm::tlm_mm_interface{
  public:
    xaxi_tlm_mm_if();
    ~xaxi_tlm_mm_if();

    xaxi_tlm_transaction* allocate();
    void free(xaxi_tlm_transaction*);
  protected:
  private:
    std::vector<xaxi_tlm_transaction* > m_trans_pool;
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
