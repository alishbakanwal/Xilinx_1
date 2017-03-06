#ifndef XTLM_V1
#define XTLM_V1

#if ! defined(SC_INCLUDE_DYNAMIC_PROCESSES)
#if defined(SYSTEMC_INCLUDED)
#error "SC_INCLUDE_DYNAMIC_PROCESSES must be defined before including systemc"
#else
#define SC_INCLUDE_DYNAMIC_PROCESSES
#endif
#endif

/* Includes */
#include <systemc>
#include "APBase.h"
#include "APBaseExt.h"
#include "xsc_ext.h"

using sc_core::SC_ID_ASSERTION_FAILED_;
#include <tlm.h>
#include <tlm_utils/simple_initiator_socket.h>
#include <tlm_utils/simple_target_socket.h>
#include <tlm_utils/multi_passthrough_target_socket.h>
#include <tlm_utils/multi_passthrough_initiator_socket.h>
//xtlm_adaptors
#include "xaxi_decls.h"

//xtlm_generic_payload
#include "xtlm_axistream_extension.h"
#include "xtlm_aximm_extension.h"
#include "xtlm_aximm_protocol_extension.h"
#include "xtlm_generic_payload.h"

//xtlm_interfaces
#include "xtlm_fw_bw_ifs.h"
#include "xtlm_mm.h"
#include "xtlm_initiator_base.h"
#include "xtlm_target_base.h"
#include "xtlm_initiator_tagged_base.h"
#include "xtlm_target_tagged_base.h"

//xtlm_sockets
#include "xtlm_socket_base.h"
#include "xtlm_initiator_socket.h"
#include "xtlm_initiator_socket_t.h"
#include "xtlm_target_socket.h"
#include "xtlm_target_socket_t.h"
#include "xtlm_multi_initiator_socket.h"
#include "xtlm_multi_initiator_socket_t.h"
#include "xtlm_multi_target_socket.h"
#include "xtlm_multi_target_socket_t.h"
#include "xtlm_simple_initiator_socket_tagged.h"
#include "xtlm_simple_initiator_socket_tagged_t.h"
#include "xtlm_simple_target_socket_tagged.h"
#include "xtlm_simple_target_socket_tagged_t.h"

//xtlm_adaptors
#include "xaxi_pa_pins_base.h"
#include "xaxis_pa_if_config.h"
#include "xaxis_pa_pins.h"
#include "xaximm_pa_if_config.h"
#include "xaximm_pa_pins.h"
#include "xaxi_pa_protocol_base.h"
#include "xaxis_pa_protocol.h"
#include "xaxis_pa_slave_socket.h"
#include "xaxis_pa_master_socket.h"
#include "xaxi_handshake_rxtx.h"
#include "xaximm_rd_pa_master_protocol.h"
#include "xaximm_rd_pa_slave_protocol.h"
#include "xaximm_wr_pa_master_protocol.h"
#include "xaximm_wr_pa_slave_protocol.h"
#include "xaximm_pa_master_socket.h"
#include "xaximm_pa_slave_socket.h"

#include "model_params.h"


#endif

// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
