#ifndef XAXI_TLM
#define XAXI_TLM

#if ! defined(SC_INCLUDE_DYNAMIC_PROCESSES)
#if defined(SYSTEMC_INCLUDED)
#error "SC_INCLUDE_DYNAMIC_PROCESSES must be defined before including systemc"
#else
#define SC_INCLUDE_DYNAMIC_PROCESSES
#endif
#endif

/* Includes */
#include <systemc>
#include "xsc_ext.h"

using sc_core::SC_ID_ASSERTION_FAILED_;
#include <tlm.h>

#include "model_params.h"
#include "xaxi_handshake_rxtx.h"

#include <tlm_utils/simple_initiator_socket.h>
#include <tlm_utils/simple_target_socket.h>

#include "xaxi_decls.h"

#include "xaxi_tlm_stream_extension.h"
#include "xaximm_tlm_extension.h"
#include "xaximm_protocol_extension.h"
#include "xaxi_tlm_payload.h"
#include "xaxi_tlm_ifs.h"
#include "xaximm_tlm_mm_if.h"

#include "xaxi_tlm_slave_base.h"
#include "xaxi_tlm_master_base.h"


#include "xaxi_tlm_socket_base.h"
//#include "xaxi_tlm_slave_socket_t.h"
//#include "xaxi_tlm_master_socket_t.h"
#include "xaxi_tlm_socket_factory.h"
#include "xaxi_tlm_slave_socket.h"
#include "xaxi_tlm_master_socket.h"

#include "xaxi_pa_pins_base.h"
#include "xaxis_pa_if_config.h"
#include "xaxis_pa_pins.h"
#include "xaximm_pa_if_config.h"
#include "xaximm_pa_pins.h"
#include "xaxi_pa_protocol_base.h"

#include "xaxis_pa_protocol.h"
#include "xaxis_pa_slave_socket.h"
#include "xaxis_pa_master_socket.h"

#include "xaximm_wr_pa_slave_protocol.h"
#include "xaximm_wr_pa_master_protocol.h"
#include "xaximm_rd_pa_slave_protocol.h"
#include "xaximm_rd_pa_master_protocol.h"
#include "xaximm_pa_master_socket.h"
#include "xaximm_pa_slave_socket.h"
#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
