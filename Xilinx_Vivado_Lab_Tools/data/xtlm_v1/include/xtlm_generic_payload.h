#ifndef XTLM_V1_PAYLOAD
#define XTLM_V1_PAYLOAD

namespace xtlm_v1{
  class xtlm_axistream_extension;
  class xtlm_aximm_extension;

  struct xtlm_protocol_types{
    typedef tlm::tlm_generic_payload	tlm_payload_type;
    typedef tlm::tlm_phase				tlm_phase_type;
  };
  typedef xtlm_protocol_types::tlm_payload_type xtlm_transaction;

  class axi_trans_buf{
  public:
    axi_trans_buf(unsigned int p_streaming_width){
      gp_data_ptr = new unsigned char[4096];
      gp_data_enable_ptr = new unsigned char[4096];

      gp_data_length = 0;
      gp_data_enable_length = 0;
      gp_streaming_width = p_streaming_width;
      gp_data_ptr_location = 0;
      gp_data_enable_ptr_location = 0;

      cur_data_buf_size = 4096;
      cur_dataen_buf_size = 4096;

      axi_transaction.set_address(0x0);
      axi_transaction.set_write();
      axi_transaction.set_streaming_width(gp_streaming_width);
      axi_transaction.set_data_ptr(gp_data_ptr);
      axi_transaction.set_data_length(gp_data_length);
      axi_transaction.set_byte_enable_length
        (gp_data_enable_length);
      axi_transaction.set_byte_enable_ptr(gp_data_enable_ptr);

      burst_length = 0;
      burst_size   = 0;
 
    }
    ~axi_trans_buf(){
      delete[] gp_data_ptr;
      delete[] gp_data_enable_ptr;
    }
    void reset(){
      //cout << __FUNCTION__ << endl;
      //Retain the previously incremented size of buffers
      gp_data_length = 0;
      gp_data_enable_length = 0;

      gp_data_ptr_location = 0;
      gp_data_enable_ptr_location = 0;
    }
    void increase_data_buf_size(){
      unsigned char* temp_data_ptr = 
        (unsigned char*)malloc(cur_data_buf_size + 4096);
      memcpy(	temp_data_ptr,gp_data_ptr,cur_data_buf_size);

      delete[] gp_data_ptr;


      gp_data_ptr = temp_data_ptr;

      cur_data_buf_size += 4096;

      axi_transaction.set_data_ptr(gp_data_ptr);
    }
    void increase_dataen_buf_size(){
      unsigned char* temp_data_enable_ptr = 
        new unsigned char[cur_dataen_buf_size + 4096];

      memcpy(	temp_data_enable_ptr, gp_data_enable_ptr, 	
          cur_dataen_buf_size);

      //values, needs more testing.
      delete[] gp_data_enable_ptr;

      gp_data_enable_ptr = temp_data_enable_ptr;

      cur_dataen_buf_size += 4096;

      axi_transaction.set_byte_enable_ptr(gp_data_enable_ptr);
    }
    void write_next_data_byte(unsigned char& byte){
      if(gp_data_ptr_location >= cur_data_buf_size){
        increase_data_buf_size();
      }
      gp_data_ptr[gp_data_ptr_location] = byte;
      gp_data_ptr_location++;
      gp_data_length = gp_data_ptr_location;
      axi_transaction.set_data_length(gp_data_length); 
//      cout << __FUNCTION__ << " " << gp_data_ptr_location << endl;
    }
    void set_strb_bit_for_byte(unsigned int byte_offset,unsigned int bit){
      while(gp_data_enable_length <= ((byte_offset / 8) + ((byte_offset % 8) != 0))){
        unsigned char ch = 0x0;
        write_next_data_enable_byte(ch);
      }
      unsigned int byte_enable_index = byte_offset / 8;
      unsigned int byte_enable_offset = byte_offset % 8;

      gp_data_enable_ptr[byte_enable_index] = (gp_data_enable_ptr[byte_enable_index]) | (bit << byte_enable_offset);
    };
    void write_next_data_enable_byte(unsigned char& byte){
      if(gp_data_enable_ptr_location >= cur_dataen_buf_size){
        increase_dataen_buf_size();
      }
      gp_data_enable_ptr[gp_data_enable_ptr_location] = byte; 
      gp_data_enable_ptr_location++;
      gp_data_enable_length = gp_data_enable_ptr_location;
      axi_transaction.set_byte_enable_length(gp_data_enable_length); 
    };
    xtlm_axistream_extension* get_axis_extension(){
      return dynamic_cast<xtlm_axistream_extension*> (
          axi_transaction.get_extension(0)
          );
    }
    void set_axis_extension(xtlm_axistream_extension* ext){
      //extension object may not be set twice
      assert(axi_transaction.get_extension(0) == NULL);
      axi_transaction.set_extension(0,ext);
    }

    xtlm_aximm_extension* get_aximm_extension(){
      return dynamic_cast<xtlm_aximm_extension*> (
          axi_transaction.get_extension(0)
          );
    }
    void set_aximm_extension(xtlm_aximm_extension* ext){
      //extension object may not be set twice
      assert(axi_transaction.get_extension(0) == NULL);
      axi_transaction.set_extension(0,ext);
    }

    void set_burst_length(unsigned int p_burst_length){
      burst_length = p_burst_length;
    }
    unsigned int get_burst_length(){
      return burst_length;
    }
    void set_burst_size(unsigned int p_burst_size){
      burst_size = p_burst_size;
    }
    unsigned int get_burst_size(){
      return burst_size;
    }
    bool is_burst_complete(){
      unsigned int beats = ((gp_data_ptr_location ) / (gp_streaming_width/8));
      return beats == burst_length;
    }
    void set_id(unsigned int p_id){
      xtlm_aximm_extension* ext = get_aximm_extension();
      if(ext)
      {
        ext->trans_id = p_id;
      }
      else
      {
        xtlm_axistream_extension* ext = get_axis_extension();
        if(ext)
        {
            ext->id = p_id;
        }
      }

    }
    unsigned int get_id(){
    xtlm_aximm_extension* ext = get_aximm_extension();
      if(ext)
      {
        return ext->trans_id;
      }
      else
      {
        xtlm_axistream_extension* ext = get_axis_extension();
        if(ext)
        {
            return ext->id;
        }
        else
        {
          return 0;
        }
      }

    }
    xtlm_transaction axi_transaction;

    unsigned char* gp_data_ptr;
    unsigned char* gp_data_enable_ptr;			

    unsigned int gp_data_length;
    unsigned int gp_data_enable_length;
    unsigned int gp_streaming_width;

    unsigned int gp_data_ptr_location;
    unsigned int gp_data_enable_ptr_location;

    unsigned int cur_data_buf_size;
    unsigned int cur_dataen_buf_size;

    unsigned int burst_length;
    unsigned int burst_size;

  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
