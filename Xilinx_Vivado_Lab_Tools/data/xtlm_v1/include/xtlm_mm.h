#include <vector>
#ifndef XTLM_V1_MM_IF
#define XTLM_V1_MM_IF
namespace xtlm_v1{
  class xtlm_mm:public virtual tlm::tlm_mm_interface{
  public:
    xtlm_mm();
    ~xtlm_mm();
    static xtlm_mm* get_instance();

    xtlm_transaction* get_trans_object();
    void free(xtlm_transaction*);
    xtlm_aximm_protocol_extension* get_protocol_extension();
  protected:
  private:
    std::vector<xtlm_transaction* > m_trans_pool;
    std::vector<xtlm_aximm_protocol_extension* > m_protocol_extension_pool;
    static xtlm_mm* instance;
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
