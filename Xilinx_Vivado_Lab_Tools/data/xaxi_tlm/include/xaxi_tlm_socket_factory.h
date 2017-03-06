#include <iterator>
#include <map>

#ifndef XAXI_TLM_SOCKET_FACTORY_H
#define XAXI_TLM_SOCKET_FACTORY_H
namespace xaxi_tlm{
  class xaxi_tlm_socket_factory_imp;
  class xaxi_tlm_socket_factory{
  public:
    static xaxi_tlm_socket_factory* get_instance(){
      if(instance == NULL){
        return instance = new xaxi_tlm_socket_factory();
      }else{
        return instance;
      }
    }
    sc_core::sc_object* get_slave_socket_instance_s_0_64(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_slave_socket_instance_s_64_128(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_slave_socket_instance_s_128_192(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_slave_socket_instance_s_192_256(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_slave_socket_instance_s_256_320(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_slave_socket_instance_s_320_384(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_slave_socket_instance_s_384_448(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_slave_socket_instance_s_448_512(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_slave_socket_instance(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_master_socket_instance_m_0_64(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_master_socket_instance_m_64_128(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_master_socket_instance_m_128_192(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_master_socket_instance_m_192_256(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_master_socket_instance_m_256_320(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_master_socket_instance_m_320_384(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_master_socket_instance_m_384_448(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_master_socket_instance_m_448_512(std::string& socket_name,int width,int socket_id = 0);
    sc_core::sc_object* get_master_socket_instance(std::string& socket_name,int width,int socket_id = 0);

    sc_core::sc_object* get_slave_socket(std::string& socket_name);
    sc_core::sc_object* get_master_socket(std::string& socket_name);
    ~xaxi_tlm_socket_factory();
  protected:
  private:
    static xaxi_tlm_socket_factory* instance;
    xaxi_tlm_socket_factory();
    xaxi_tlm_socket_factory_imp* p_imp;
  };

#define XAXI_TLM_SOCKET_FACTORY (*(xaxi_tlm::xaxi_tlm_socket_factory::get_instance()))

#define INSTANTIATE_MASTER_SOCKET(name,width)\
  (XAXI_TLM_SOCKET_FACTORY.get_master_socket_instance(name,width))
#define INSTANTIATE_MASTER_SOCKET_TAG(name,width,skt_id)\
  (XAXI_TLM_SOCKET_FACTORY.get_master_socket_instance(name,width,skt_id))
#define GET_MASTER_SOCKET(name)\
  (XAXI_TLM_SOCKET_FACTORY.get_master_socket(const_cast<std::string&>(name)))

#define INSTANTIATE_SLAVE_SOCKET(name,width)\
  (XAXI_TLM_SOCKET_FACTORY.get_slave_socket_instance(name,width))
#define INSTANTIATE_SLAVE_SOCKET_TAG(name,width,skt_id)\
  (XAXI_TLM_SOCKET_FACTORY.get_slave_socket_instance(name,width,skt_id))

#define GET_SLAVE_SOCKET(name)\
  (XAXI_TLM_SOCKET_FACTORY.get_slave_socket(const_cast<std::string&>(name)))
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
