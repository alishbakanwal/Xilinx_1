#ifndef XAXIMM_PA_IF_CONFIG_H
#define  XAXIMM_PA_IF_CONFIG_H
namespace xtlm_v1{
#define AXI3_PROTOCOL 0
#define AXI4_PROTOCOL 1
#define AXI4_LITE_PROTOCOL 2

#define READ_ONLY  0
#define WRITE_ONLY 1
#define READ_WRITE 2
  class xaximm_pa_if_config{
  public:
    xaximm_pa_if_config(){
      PROTOCOL = AXI4_PROTOCOL;
      ADDR_WIDTH = 32;
      ARUSER_WIDTH = 0;
      AWUSER_WIDTH = 0;
      BUSER_WIDTH = 0;
      DATA_WIDTH = 32;
      ID_WIDTH = 0;
      MAX_BURST_LENGTH = 256;
      NUM_READ_OUTSTANDING = 1;
      NUM_WRITE_OUTSTANDING = 1;
      READ_WRITE_MODE = READ_WRITE;
      RUSER_WIDTH = 0;
      SUPPORTS_NARROW_BURST = 1;
      WUSER_WIDTH = 0;
    }
    void set_protocol(unsigned int proto)
    {
      PROTOCOL = proto;
    }
    unsigned int get_protocol()
    {
      return PROTOCOL;
    }
    //READ_WRITE
    void set_read_write_model(unsigned int mode){
      assert(mode <= 2);
      READ_WRITE_MODE = mode;
    }
    bool is_read_channel_enabled(){ return READ_WRITE_MODE != WRITE_ONLY; }
    bool is_write_channel_enabled(){ return READ_WRITE_MODE != READ_ONLY; }

    //tready and tvalid are always enabled
    unsigned int get_tready_width(){return 1;}
    unsigned int get_tvalid_width(){return 1;}

    //ID
    void enable_id(bool flag,unsigned int width)	
    {
      if(flag){
        ID_WIDTH = width;
      }else{
        ID_WIDTH = 0;
      }
    }
    bool is_id_enabled(){return ID_WIDTH != 0;}
    unsigned int get_id_width(){return ID_WIDTH;}

    //ARUSER/AWUSER/RUSER/WUSER/BUSER
    void enable_addr_read_user(bool flag,unsigned int width)	
    {
      if(flag){
        ARUSER_WIDTH = width;
      }else{
        ARUSER_WIDTH = 0;
      }
    }
    void enable_addr_write_user(bool flag,unsigned int width)	
    {
      if(flag){
        AWUSER_WIDTH = width;
      }else{
        AWUSER_WIDTH = 0;
      }
    }
    void enable_read_user(bool flag,unsigned int width)	
    {
      if(flag){
        RUSER_WIDTH = width;
      }else{
        RUSER_WIDTH = 0;
      }
    }
    void enable_write_user(bool flag,unsigned int width)	
    {
      if(flag){
        WUSER_WIDTH = width;
      }else{
        WUSER_WIDTH = 0;
      }
    }
    void enable_write_resp_user(bool flag,unsigned int width)	
    {
      if(flag){
        BUSER_WIDTH = width;
      }else{
        BUSER_WIDTH = 0;
      }
    }
    bool is_addr_read_user_enabled(){return ARUSER_WIDTH != 0;}
    bool is_addr_write_user_enabled(){return AWUSER_WIDTH != 0;}
    bool is_read_user_enabled(){return RUSER_WIDTH != 0;}
    bool is_write_user_enabled(){return WUSER_WIDTH != 0;}
    bool is_write_resp_user_enabled(){return BUSER_WIDTH != 0;}
    unsigned int get_addr_read_user_width(){return ARUSER_WIDTH;}
    unsigned int get_addr_write_user_width(){return AWUSER_WIDTH;}
    unsigned int get_read_user_width(){return RUSER_WIDTH;}
    unsigned int get_write_user_width(){return WUSER_WIDTH;}
    unsigned int get_write_resp_user_width(){return BUSER_WIDTH;}
    unsigned int get_num_write_outstanding() {return NUM_WRITE_OUTSTANDING;}
    unsigned int get_num_read_outstanding() {return NUM_READ_OUTSTANDING;}
    void set_num_write_outstanding(unsigned int n_wr_outstanding) {NUM_WRITE_OUTSTANDING = n_wr_outstanding;}
    void set_num_read_outstanding(unsigned int n_rd_outstanding) {NUM_READ_OUTSTANDING = n_rd_outstanding;}

    //address is always enabled
    //ADDR_WIDTH
    void set_address_width(unsigned int width)
    {
      ADDR_WIDTH = width;
    }
    unsigned int get_address_width(){
      return ADDR_WIDTH;
    }
    //data is always enabled
    //DATA_WIDTH
    void set_data_width(unsigned int width)
    {
      DATA_WIDTH = width;
    }
    unsigned int get_data_width(){
      return DATA_WIDTH;
    }

    //BURST_TYPE and BURST_LEN pins have fixed values
    unsigned int get_burst_size_width(){return 3;}
    unsigned int get_burst_len_width()
    {
      if(PROTOCOL == AXI3_PROTOCOL) return 4;
      if(PROTOCOL == AXI4_PROTOCOL) return 8;
      //AWLEN or ARLEN fields are not required
      if(PROTOCOL == AXI4_LITE_PROTOCOL) return 0;
      assert(0);
      return -1;
    }
    unsigned int get_burst_type_width(){
      return 2;
    }

    //used to determine AXI3/AXI4 protocol
    void set_max_burst_length(unsigned int length)
    {
      MAX_BURST_LENGTH = length;
    }

    bool is_aximm_ext_required(){
      return (
          is_id_enabled()
          || is_addr_read_user_enabled() 
          || is_addr_write_user_enabled()
          || is_read_user_enabled()
          || is_write_user_enabled()
          || is_write_resp_user_enabled()
          );
    }

  protected:
  private:

    unsigned int READ_WRITE_MODE;//READ_WRITE

    unsigned int ADDR_WIDTH;//32
    unsigned int DATA_WIDTH;//32

    unsigned int ARUSER_WIDTH;//0
    unsigned int AWUSER_WIDTH;//0
    unsigned int BUSER_WIDTH;//0
    unsigned int WUSER_WIDTH;//0
    unsigned int RUSER_WIDTH;//0

    unsigned int ID_WIDTH;//0

    unsigned int PROTOCOL;
    //used to determine the protocol
    //16 = AXI3
    //256 = AXI4
    unsigned int MAX_BURST_LENGTH;//256

    //TBD what is this used for? might be effective in protocol implementation
    unsigned int NUM_READ_OUTSTANDING;//1
    unsigned int NUM_WRITE_OUTSTANDING;//1

    //TBD what is this used for? might be effective in protocol implementation
    unsigned int SUPPORTS_NARROW_BURST;//1
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
