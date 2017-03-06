#ifndef XAXI_TLM_SOCKET_BASE_H
#define XAXI_TLM_SOCKET_BASE_H
namespace xaxi_tlm{
  class xaxi_tlm_socket_base{
  public:
    explicit xaxi_tlm_socket_base(int p_socket_id){m_socket_id = p_socket_id;}
    void set_socket_id(int p_socket_id){m_socket_id = p_socket_id;}
    int get_socket_id(){return m_socket_id;}
  protected:
  private:
    int m_socket_id;
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
