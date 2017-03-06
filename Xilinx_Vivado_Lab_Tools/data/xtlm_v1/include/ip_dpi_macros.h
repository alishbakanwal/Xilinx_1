#ifndef SV_IF_MACROS
#define SV_IF_MACROS

//---------------------------------------------------
//STREAMING
//---------------------------------------------------
//TBD : Scalar pins
#define SET_AXIS_PIN_VAL(ip_name,pin_name,svcpp_name) svcpp_name = IP_MODEL_INST(ip_name).pin_name.to_uint();

#define SET_AXIS_PIN_VALARRAY(ip_name,pin_name,svcpp_name)\
{\
  unsigned int length = IP_MODEL_INST(ip_name).pin_name->length();\
  memcpy(\
            svcpp_name, \
            (IP_MODEL_INST.pin_name)->get_pVal(), \
            (length >> 3) + ( (length%8 != 0) ? 1 : 0 ) \
            );\
}


#define GET_AXIS_INTF_VAL(ip_name,intf_name,intf_pin_name,hdl_pin_name) \
  hdl_pin_name = (IP_MODEL_INST(ip_name).intf_name)->xaxis_skt_pin_if.get_pin(XAXIS_ENUM_##intf_pin_name).to_uint();

#define GET_AXIS_INTF_VALARRAY(ip_name,intf_name,intf_pin_name,hdl_pin_name) \
{\
  unsigned int length = (IP_MODEL_INST(ip_name).intf_name)->xaxis_skt_pin_if.get_pin(XAXIS_ENUM_##intf_pin_name).length();\
  memcpy(\
            hdl_pin_name, \
            (IP_MODEL_INST(ip_name).intf_name)->xaxis_skt_pin_if.get_pin(XAXIS_ENUM_##intf_pin_name).get_pVal(), \
            (length >> 3) + ( (length%8 != 0) ? 1 : 0 ) \
            );\
}

//---------------------------------------------------
//TBD : Scalar pins
#define GET_AXIS_PIN_VAL(ip_name,pin_name,svcpp_name) IP_MODEL_INST(ip_name).pin_name = svcpp_name;

#define GET_AXIS_PIN_VALARRAY(ip_name,pin_name,svcpp_name)\
{\
  unsigned int length = IP_MODEL_INST(ip_name).pin_name->length();\
  memcpy(\
            IP_MODEL_INST(ip_name).pin_name->get_pVal(), \
            svcpp_name,\
            (length >> 3) + ( (length%8 != 0) ? 1 : 0 ) \
            );\
}

#define SET_AXIS_INTF_VAL(ip_name,intf_name,intf_pin_name,hdl_pin_name) \
{\
  (IP_MODEL_INST(ip_name).intf_name)->xaxis_skt_pin_if.set_pin_val(XAXIS_ENUM_##intf_pin_name,(hdl_pin_name == 1)); \
}

#define SET_AXIS_INTF_VALARRAY(ip_name,intf_name,intf_pin_name,hdl_pin_name) \
{\
  unsigned int length = (IP_MODEL_INST(ip_name).intf_name)->xaxis_skt_pin_if.get_pin(XAXIS_ENUM_##intf_pin_name).length();\
  memcpy(\
            (IP_MODEL_INST(ip_name).intf_name)->xaxis_skt_pin_if.get_pin(XAXIS_ENUM_##intf_pin_name).get_pVal(), \
            hdl_pin_name,\
            (length >> 3) + ( (length%8 != 0) ? 1 : 0 ) \
            );\
}
//---------------------------------------------------
//---------------------------------------------------
//AXIMM
//---------------------------------------------------
//TBD : Scalar pins
#define SET_AXIMM_PIN_VAL(ip_name,pin_name,svcpp_name) svcpp_name = IP_MODEL_INST(ip_name).pin_name.to_uint();

#define SET_AXIMM_PIN_VALARRAY(ip_name,pin_name,svcpp_name)\
{\
  unsigned int length = IP_MODEL_INST(ip_name).pin_name->length();\
  memcpy(\
            svcpp_name,\
            IP_MODEL_INST(ip_name).pin_name->get_pVal(), \
            (length >> 3) + ( (length%8 != 0) ? 1 : 0 ) \
            );\
}

//type op_type rd/wr intf_type master/slave data_type addr data resp 
#define GET_AXIMM_INTF_VAL(ip_name,op_type,intf_type,data_type,intf_name,intf_pin_name,hdl_pin_name) \
  hdl_pin_name = (IP_MODEL_INST(ip_name).intf_name)->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.get_pin(XAXIMM_ENUM_##intf_pin_name).to_uint();

#define GET_AXIMM_INTF_VALARRAY(ip_name,op_type,intf_type,data_type,intf_name,intf_pin_name,hdl_pin_name) \
{\
  unsigned int length = (IP_MODEL_INST(ip_name).intf_name)->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.get_pin(XAXIMM_ENUM_##intf_pin_name).length();\
  memcpy(\
            hdl_pin_name,\
            (IP_MODEL_INST(ip_name).intf_name)->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.get_pin(XAXIMM_ENUM_##intf_pin_name).get_pVal(), \
            (length >> 3) + ( (length%8 != 0) ? 1 : 0 ) \
            );\
}

//---------------------------------------------------
//TBD : Scalar pins
#define GET_AXIMM_PIN_VAL(ip_name,pin_name,svcpp_name) IP_MODEL_INST(ip_name).pin_name = svcpp_name;

#define GET_AXIS_PIN_VALARRAY(ip_name,pin_name,svcpp_name)\
{\
  unsigned int length = IP_MODEL_INST(ip_name).pin_name->length();\
  memcpy(\
            IP_MODEL_INST(ip_name).pin_name->get_pVal(), \
            svcpp_name,\
            (length >> 3) + ( (length%8 != 0) ? 1 : 0 ) \
            );\
}

#define SET_AXIMM_INTF_VAL(ip_name,op_type,intf_type,data_type,intf_name,intf_pin_name,hdl_pin_name) \
{\
  (IP_MODEL_INST(ip_name).intf_name)->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.set_pin_val(XAXIMM_ENUM_##intf_pin_name,(hdl_pin_name == 1)); \
}

#define SET_AXIMM_INTF_VALARRAY(ip_name,op_type,intf_type,data_type,intf_name,intf_pin_name,hdl_pin_name) \
{\
  unsigned int length = (IP_MODEL_INST(ip_name).intf_name)->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.get_pin(XAXIMM_ENUM_##intf_pin_name).length();\
  memcpy(\
            (IP_MODEL_INST(ip_name).intf_name)->op_type##_##intf_type##_socket.xaximm_##op_type##_##data_type##_skt_pin_if.get_pin(XAXIMM_ENUM_##intf_pin_name).get_pVal(), \
            hdl_pin_name,\
            (length >> 3) + ( (length%8 != 0) ? 1 : 0 ) \
            );\
}
//---------------------------------------------------

#endif


// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
