#ifndef SV_IF_MACROS
#define SV_IF_MACROS

//---------------------------------------------------
//STREAMING
//---------------------------------------------------
//TBD : Scalar pins
#define SET_AXIS_PIN_VAL(ip_name,pin_name,svcpp_name) svcpp_name = IP_MODEL_INST.pin_name.to_uint();

#define SET_AXIS_PIN_VALARRAY(ip_name,pin_name,svcpp_name)\
{\
  unsigned int length = IP_MODEL_INST.pin_name->length();\
  for(int i = 0; i < length/32;i++){\
    svcpp_name[i] = (IP_MODEL_INST.pin_name)->range((i<<5)+31,(i<<5)).to_uint();\
  }\
  if(length%32 != 0){\
    unsigned int lo = ((length/32)*32);\
    unsigned int hi = length - 1;\
    unsigned int buf_idx   = (length/32);\
    svcpp_name[buf_idx] = (IP_MODEL_INST.pin_name)->range(hi,lo).to_uint();\
  }\
}


#define GET_AXIS_INTF_VAL(ip_name,intf_name,intf_pin_name,hdl_pin_name) \
  hdl_pin_name = (IP_MODEL_INST.intf_name)->xaxis_skt_pin_if.get_pin(XAXIS_ENUM_##intf_pin_name).to_uint();

#define GET_AXIS_INTF_VALARRAY(ip_name,intf_name,intf_pin_name,hdl_pin_name) \
{\
  unsigned int length = (IP_MODEL_INST.intf_name)->xaxis_skt_pin_if.get_pin(XAXIS_ENUM_##intf_pin_name).length();\
  for(int i = 0; i < length/32;i++){\
    hdl_pin_name[i] = (IP_MODEL_INST.intf_name)->xaxis_skt_pin_if.get_pin(XAXIS_ENUM_##intf_pin_name).range((i<<5)+31,(i<<5)).to_uint();\
  }\
  if(length%32 != 0){\
    unsigned int lo = ((length/32)*32);\
    unsigned int hi = length - 1;\
    unsigned int buf_idx   = (length/32);\
    hdl_pin_name[buf_idx] = (IP_MODEL_INST.intf_name)->xaxis_skt_pin_if.get_pin(XAXIS_ENUM_##intf_pin_name).range(hi,lo).to_uint();\
  }\
}

//---------------------------------------------------
//TBD : Scalar pins
#define GET_AXIS_PIN_VAL(ip_name,pin_name,svcpp_name) IP_MODEL_INST.pin_name = svcpp_name;

#define GET_AXIS_PIN_VALARRAY(ip_name,pin_name,svcpp_name)\
{\
  unsigned int length = IP_MODEL_INST.pin_name->length();\
  for(int i = 0; i < length/32;i+=1){\
    IP_MODEL_INST.pin_name->range(int((i<<5)+31), int(i<<5)) = svcpp_name[i];\
  }\
  if(length%32 != 0){\
    unsigned int lo = ((length>>5)<<5);\
    unsigned int hi = length - 1;\
    unsigned int buf_idx   = (length/32);\
    xsc_bv value(length%32,svcpp_name[buf_idx]);\
    (IP_MODEL_INST.pin_name)->range(hi,lo) = value;\
  }\
}

#define SET_AXIS_INTF_VAL(ip_name,intf_name,intf_pin_name,hdl_pin_name) \
{\
  (IP_MODEL_INST.intf_name)->xaxis_skt_pin_if.set_pin_val(XAXIS_ENUM_##intf_pin_name,(hdl_pin_name == 1)); \
}

#define SET_AXIS_INTF_VALARRAY(ip_name,intf_name,intf_pin_name,hdl_pin_name) \
{\
  unsigned int length = (IP_MODEL_INST.intf_name)->xaxis_skt_pin_if.get_pin(XAXIS_ENUM_##intf_pin_name).length();\
  for(int i = 0; i < length/32;i+=1){\
    (IP_MODEL_INST.intf_name)->xaxis_skt_pin_if.get_pin(XAXIS_ENUM_##intf_pin_name).range(int((i<<5)+31), int(i<<5)) = hdl_pin_name[i];\
  }\
  if(length%32 != 0){\
    unsigned int lo = ((length>>5)<<5);\
    unsigned int hi = length - 1;\
    unsigned int buf_idx   = (length/32);\
    xsc_bv value(length%32,hdl_pin_name[buf_idx]); \
    (IP_MODEL_INST.intf_name)->xaxis_skt_pin_if.get_pin(XAXIS_ENUM_##intf_pin_name).range(hi,lo) = value;\		}\
}
//---------------------------------------------------
//---------------------------------------------------
//AXIMM
//---------------------------------------------------
//TBD : Scalar pins
#define SET_AXIMM_PIN_VAL(ip_name,pin_name,svcpp_name) svcpp_name = IP_MODEL_INST.pin_name.to_uint();

#define SET_AXIMM_PIN_VALARRAY(ip_name,pin_name,svcpp_name)\
{\
  unsigned int length = IP_MODEL_INST.pin_name->length();\
  for(int i = 0; i < length/32;i++){\
    svcpp_name[i] = (IP_MODEL_INST.pin_name)->range((i<<5)+31,(i<<5)).to_uint();\
  }\
  if(length%32 != 0){\
    unsigned int lo = ((length/32)*32);\
    unsigned int hi = length - 1;\
    unsigned int buf_idx   = (length/32);\
    svcpp_name[buf_idx] = (IP_MODEL_INST.pin_name)->range(hi,lo).to_uint();\
  }\
}

#define AXIMM_INTF_PIN(pa_inst,op_type,intf_type,data_type,intf_name,intf_pin_name,hdl_pin_name) \
  pa_inst->intf_name->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.get_pin(XAXIMM_ENUM_##intf_pin_name)

//type op_type rd/wr intf_type master/slave data_type addr data resp 
#define GET_AXIMM_INTF_VAL(ip_name,op_type,intf_type,data_type,intf_name,intf_pin_name,hdl_pin_name) \
  hdl_pin_name = (IP_MODEL_INST.intf_name)->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.get_pin(XAXIMM_ENUM_##intf_pin_name).to_uint();

#define GET_AXIMM_INTF_VALARRAY(ip_name,op_type,intf_type,data_type,intf_name,intf_pin_name,hdl_pin_name) \
{\
  unsigned int length = (IP_MODEL_INST.intf_name)->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.get_pin(XAXIMM_ENUM_##intf_pin_name).length();\
  for(int i = 0; i < length/32;i++){\
    hdl_pin_name[i] = (IP_MODEL_INST.intf_name)->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.get_pin(XAXIMM_ENUM_##intf_pin_name).range((i<<5)+31,(i<<5)).to_uint();\
  }\
  if(length%32 != 0){\
    unsigned int lo = ((length/32)*32);\
    unsigned int hi = length - 1;\
    unsigned int buf_idx   = (length/32);\
    hdl_pin_name[buf_idx] = (IP_MODEL_INST.intf_name)->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.get_pin(XAXIMM_ENUM_##intf_pin_name).range(hi,lo).to_uint();\
  }\
}

//---------------------------------------------------
//TBD : Scalar pins
#define GET_AXIMM_PIN_VAL(ip_name,pin_name,svcpp_name) IP_MODEL_INST.pin_name = svcpp_name;

#define GET_AXIS_PIN_VALARRAY(ip_name,pin_name,svcpp_name)\
{\
  unsigned int length = IP_MODEL_INST.pin_name->length();\
  for(int i = 0; i < length/32;i+=1){\
    IP_MODEL_INST.pin_name->range(int((i<<5)+31), int(i<<5)) = svcpp_name[i];\
  }\
  if(length%32 != 0){\
    unsigned int lo = ((length>>5)<<5);\
    unsigned int hi = length - 1;\
    unsigned int buf_idx   = (length/32);\
    xsc_bv value(length%32,svcpp_name[buf_idx]);\
    (IP_MODEL_INST.pin_name)->range(hi,lo) = value;\
  }\
}

#define SET_AXIMM_INTF_VAL(pa_inst,op_type,intf_type,data_type,intf_name,intf_pin_name,hdl_pin_name) \
{\
  pa_inst->intf_name->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.set_pin_val(XAXIMM_ENUM_##intf_pin_name,(hdl_pin_name == 1)); \
}

#define SET_AXIMM_INTF_VALARRAY(pa_inst,op_type,intf_type,data_type,intf_name,intf_pin_name,hdl_pin_name) \
{\
  unsigned int length = pa_inst->intf_name->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.get_pin(XAXIMM_ENUM_##intf_pin_name).length();\
  for(int i = 0; i < length/32;i+=1){\
    pa_inst->intf_name->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.get_pin(XAXIMM_ENUM_##intf_pin_name).range(int((i<<5)+31), int(i<<5)) = hdl_pin_name[i];\
  }\
  if(length%32 != 0){\
    unsigned int lo = ((length>>5)<<5);\
    unsigned int hi = length - 1;\
    unsigned int buf_idx   = (length/32);\
    xsc_bv value(length%32,hdl_pin_name[buf_idx]); \
    pa_inst->intf_name->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.get_pin(XAXIMM_ENUM_##intf_pin_name).range(hi,lo) = value;\		}\
}
//---------------------------------------------------

#endif


// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
