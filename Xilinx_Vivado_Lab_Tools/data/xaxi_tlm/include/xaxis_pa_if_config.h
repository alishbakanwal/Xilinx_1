#ifndef XAXI_PA_IF_CONFIG_H
#define  XAXI_PA_IF_CONFIG_H
namespace xaxi_tlm{
  class xaxis_pa_if_config{
  public:
    //Template
    //		config_0(  	/*enable_tready*/,
    //			   	/*enable_tstrb*/,
    //			   	/*enable_tlast*/,
    //			   	/*enable_tdata*/,
    //			   	/*tdata_width*/,
    //			   	/*enable_tdest*/,
    //			   	/*tdest_width*/,
    //			   	/*enable_tid*/,
    //			   	/*tid_width*/,
    //			   	/*enable_tuser*/,
    //			   	/*tuser_width*/),

    xaxis_pa_if_config(bool enable_tready,
        bool enable_tstrb,
        bool enable_tlast,
        bool enable_tdata,
        int tdata_width,
        bool enable_tdest,
        int tdest_width,
        bool enable_tid,
        int tid_width,
        bool enable_tuser,
        int tuser_width){
      HAS_TREADY = enable_tready;
      HAS_TSTRB  = enable_tstrb;
      HAS_TLAST  = enable_tlast;

      if(enable_tdata == false){
        TDATA_NUM_BYTES = 0;
      }else{
        assert(tdata_width % 8 == 0);
        TDATA_NUM_BYTES = tdata_width/8;
      }

      if(enable_tdest == false){
        TDEST_WIDTH = 0;
      }else{
        TDEST_WIDTH = tdest_width;
      }

      if(enable_tid == false){
        TID_WIDTH = 0;
      }else{
        TID_WIDTH = tid_width;
      }

      if(enable_tuser == false){
        TUSER_WIDTH = 0;
      }else{
        TUSER_WIDTH = tuser_width;
      }
    }
    xaxis_pa_if_config(){
      HAS_TREADY = false;
      HAS_TSTRB  = false;
      HAS_TLAST  = false;
      TDATA_NUM_BYTES = 0;
      TDEST_WIDTH 	= 0;
      TID_WIDTH 	= 0;
      TUSER_WIDTH	= 0;
    }

    void enable_tready(bool flag)	{HAS_TREADY = flag;}
    void enable_tstrb(bool flag)	{HAS_TSTRB  = flag;}
    void enable_tlast(bool flag)    {HAS_TLAST  = flag;}
    void enable_tdata(bool flag, int width) 
    { 
      if(flag == false){
        TDATA_NUM_BYTES = 0;
      }else{
        assert(width % 8 == 0);
        TDATA_NUM_BYTES = width/8;
      }
    }
    void enable_tdest(bool flag, int width) 
    { 
      if(flag == false){
        TDEST_WIDTH = 0;
      }else{
        TDEST_WIDTH = width;
      }
    }
    void enable_tid(bool flag, int width) 
    { 
      if(flag == false){
        TID_WIDTH = 0;
      }else{
        TID_WIDTH = width;
      }
    }	
    void enable_tuser(bool flag, int width) 
    { 
      if(flag == false){
        TUSER_WIDTH = 0;
      }else{
        TUSER_WIDTH = width;
      }
    }

    bool is_axis_ext_required(){
      return (	   is_tdest_enabled() 
          || is_tid_enabled()
          || is_tuser_enabled()
          );
    }

    bool is_tready_enabled(){return HAS_TREADY;}
    bool is_tstrb_enabled() {return HAS_TSTRB;}
    bool is_tlast_enabled() {return HAS_TLAST;}
    bool is_tdata_enabled() {return TDATA_NUM_BYTES != 0;}
    bool is_tdest_enabled() {return TDEST_WIDTH     != 0;}
    bool is_tid_enabled()   {return TID_WIDTH       != 0;}
    bool is_tuser_enabled() {return TUSER_WIDTH     != 0;}

    unsigned int get_tvalid_width(){return 1;}
    unsigned int get_tready_width(){return 1;}
    unsigned int get_tstrb_width(){return TDATA_NUM_BYTES;}
    unsigned int get_tlast_width(){return 1;}
    unsigned int get_tdata_width(){return TDATA_NUM_BYTES*8;}
    unsigned int get_tdest_width(){return TDEST_WIDTH;}
    unsigned int get_tid_width()  {return TID_WIDTH;}
    unsigned int get_tuser_width(){return TUSER_WIDTH;}
  protected:
  private:
    bool HAS_TREADY;
    bool HAS_TSTRB;
    bool HAS_TLAST;

    int TDATA_NUM_BYTES;
    int TDEST_WIDTH;
    int TID_WIDTH;
    int TUSER_WIDTH;
  };
}
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
